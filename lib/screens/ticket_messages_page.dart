import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/tickets_service.dart';
import '../api/messages_service.dart';
import '../models/chat_models.dart';
import '../config.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';

class TicketMessagesPage extends StatefulWidget {
  final ApiClient client;
  final int ticketNumber;
  final String? ticketSubject;
  final String? clientName;
  final String? clientPhone;
  final bool showAppBar;

  const TicketMessagesPage({
    super.key,
    required this.client,
    required this.ticketNumber,
    this.ticketSubject,
    this.clientName,
    this.clientPhone,
    this.showAppBar = true,
  });

  @override
  State<TicketMessagesPage> createState() => _TicketMessagesPageState();
}

class _TicketMessagesPageState extends State<TicketMessagesPage> {
  late final TicketsService _tickets;
  late final MessagesService _messages;
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<MessageDto> _items = [];
  bool _loading = false;
  bool _sending = false;
  String? _error;
  Timer? _poller;

  // Аудио-плеер
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingAudioUrl;
  bool _isAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    _tickets = TicketsService(widget.client);
    _messages = MessagesService(widget.client);
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _audioPlayer.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted) return;
      if (_loading || _sending) return;
      try {
        await _loadMessages(showLoading: false);
      } catch (_) {
        // Игнорируем ошибки опроса
      }
    });
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    final currentOffset = _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;
    final isAtBottom = _scrollCtrl.hasClients
        ? _scrollCtrl.offset <= 10.0
        : true;
    final oldLength = _items.length;

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _tickets.getMessages(widget.ticketNumber);
      final messages = data
          .map((e) => MessageDto.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();

      if (mounted) {
        setState(() {
          _items = messages;
          if (showLoading) _loading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollCtrl.hasClients) return;
          if (isAtBottom || oldLength == 0) {
            _scrollCtrl.jumpTo(0.0);
          } else {
            // Сохраняем позицию
            final newLength = _items.length;
            if (newLength > oldLength) {
              final diff = newLength - oldLength;
              final itemHeight = 80.0; // примерная высота сообщения
              _scrollCtrl.jumpTo(currentOffset + (diff * itemHeight));
            } else {
              _scrollCtrl.jumpTo(currentOffset);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          if (showLoading) _loading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    try {
      await _messages.sendByTicket(
        ticketNumber: widget.ticketNumber,
        text: text,
      );

      _textCtrl.clear();
      await _loadMessages(showLoading: false);

      // Прокручиваем вниз после отправки
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Тикет #${widget.ticketNumber}'),
                  if (widget.clientName?.isNotEmpty == true ||
                      widget.clientPhone?.isNotEmpty == true)
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (widget.clientName?.isNotEmpty == true)
                                widget.clientName!,
                              if (widget.clientPhone?.isNotEmpty == true)
                                widget.clientPhone!,
                            ].join(' • '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (widget.ticketSubject?.isNotEmpty == true)
                    Text(
                      widget.ticketSubject!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadMessages,
                  tooltip: 'Обновить',
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _items.isEmpty
                ? _buildError()
                : _buildMessagesList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMessages,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет сообщений',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final msg = _items[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(MessageDto msg) {
    final isFromMe = msg.fromMe;
    final isMediaMessage = msg.type != 'text' && msg.mediaUrl != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isFromMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(isMediaMessage ? 4 : 14),
              decoration: BoxDecoration(
                color: isFromMe
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isFromMe ? 16 : 4),
                  bottomRight: Radius.circular(isFromMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Имя отправителя для входящих сообщений
                  if (!isFromMe && msg.senderJid != null) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMediaMessage ? 10 : 0,
                        vertical: isMediaMessage ? 6 : 0,
                      ),
                      child: Text(
                        _formatSenderName(msg.senderJid!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    if (isMediaMessage) const SizedBox(height: 4),
                  ],
                  // Имя оператора для исходящих сообщений
                  if (msg.senderUser != null && isFromMe) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMediaMessage ? 10 : 0,
                        vertical: isMediaMessage ? 6 : 0,
                      ),
                      child: Text(
                        msg.senderUser!.name ??
                            msg.senderUser!.email ??
                            'Оператор',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    if (isMediaMessage) const SizedBox(height: 4),
                  ],
                  // Отображение медиа-контента
                  if (isMediaMessage) _buildMediaContent(msg, isFromMe),
                  // Отображение текста/подписи
                  if (msg.content.isNotEmpty) ...[
                    if (isMediaMessage) const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMediaMessage ? 10 : 0,
                        vertical: isMediaMessage ? 6 : 0,
                      ),
                      child: Text(
                        msg.content,
                        style: TextStyle(
                          fontSize: 15,
                          color: isFromMe
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.only(
                      left: isMediaMessage ? 10 : 0,
                      right: isMediaMessage ? 10 : 0,
                      top: 4,
                      bottom: isMediaMessage ? 6 : 0,
                    ),
                    child: Text(
                      _formatTime(msg.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            (isFromMe
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface)
                                .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isFromMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaContent(MessageDto msg, bool isFromMe) {
    final mediaUrl = '${AppConfig.baseUrl}${msg.mediaUrl}';

    switch (msg.type) {
      case 'image':
        return GestureDetector(
          onTap: () => _openImageViewer(mediaUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 400),
              child: Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 200,
                    height: 200,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey.shade200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'Ошибка загрузки',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      case 'video':
        return Container(
          width: 250,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline, size: 64, color: Colors.white),
              const SizedBox(height: 8),
              Text('Видео', style: TextStyle(color: Colors.white)),
            ],
          ),
        );
      case 'document':
        return GestureDetector(
          onTap: () => _openDocument(mediaUrl, msg.content),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFromMe
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Документ',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Нажмите для открытия',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.download,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      case 'audio':
        final isPlaying = _playingAudioUrl == mediaUrl && _isAudioPlaying;
        return GestureDetector(
          onTap: () => _playAudio(mediaUrl),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFromMe
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  isPlaying ? 'Воспроизведение...' : 'Голосовое сообщение',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                decoration: InputDecoration(
                  hintText: 'Введите сообщение...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_sending,
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _sendMessage,
              icon: _sending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send),
              tooltip: 'Отправить',
            ),
          ],
        ),
      ),
    );
  }

  // Открытие изображения в полноэкранном режиме
  void _openImageViewer(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImageViewerPage(imageUrl: imageUrl),
      ),
    );
  }

  // Открытие/скачивание документа
  void _openDocument(String documentUrl, String? filename) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Открыть в браузере'),
              onTap: () {
                Navigator.pop(context);
                _launchUrl(documentUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Скачать'),
              onTap: () {
                Navigator.pop(context);
                _downloadDocument(documentUrl, filename);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Поделиться'),
              onTap: () {
                Navigator.pop(context);
                _shareDocument(documentUrl);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Открытие URL в браузере
  void _launchUrl(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Открытие: $url'),
        action: SnackBarAction(
          label: 'Копировать',
          onPressed: () {
            // Копирование URL в буфер обмена
          },
        ),
      ),
    );
  }

  // Скачивание документа
  void _downloadDocument(String url, String? filename) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Загрузка: ${filename ?? "документа"}...'),
        duration: const Duration(seconds: 2),
      ),
    );
    // Здесь должна быть реализация скачивания через dio или http
  }

  // Поделиться документом
  void _shareDocument(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция "Поделиться" будет добавлена'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Воспроизведение аудио
  Future<void> _playAudio(String audioUrl) async {
    try {
      if (_playingAudioUrl == audioUrl && _isAudioPlaying) {
        // Остановка текущего воспроизведения
        await _audioPlayer.stop();
        setState(() {
          _isAudioPlaying = false;
          _playingAudioUrl = null;
        });
      } else {
        // Остановка предыдущего аудио, если играет другое
        if (_isAudioPlaying) {
          await _audioPlayer.stop();
        }

        // Запуск нового аудио
        setState(() {
          _isAudioPlaying = true;
          _playingAudioUrl = audioUrl;
        });

        // Устанавливаем источник и воспроизводим
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();

        // Слушаем завершение воспроизведения
        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) {
              setState(() {
                _isAudioPlaying = false;
                _playingAudioUrl = null;
              });
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
          _playingAudioUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inDays == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Вчера ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else {
      return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatSenderName(String senderJid) {
    // Извлекаем номер телефона из JID (например, "77066520933@s.whatsapp.net" -> "77066520933")
    final phoneNumber = senderJid.split('@').first;

    // Форматируем номер телефона для более удобного отображения
    if (phoneNumber.length >= 10) {
      // Пример: 77066520933 -> +7 706 652 09 33
      if (phoneNumber.startsWith('7') && phoneNumber.length == 11) {
        return '+7 ${phoneNumber.substring(1, 4)} ${phoneNumber.substring(4, 7)} ${phoneNumber.substring(7, 9)} ${phoneNumber.substring(9)}';
      }
      // Для других форматов просто добавляем +
      return '+$phoneNumber';
    }

    // Если не получилось распознать, возвращаем как есть
    return phoneNumber;
  }
}

/// Полноэкранный просмотр изображения
class _ImageViewerPage extends StatelessWidget {
  final String imageUrl;

  const _ImageViewerPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Загрузка изображения...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Скачать',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ошибка загрузки изображения',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
