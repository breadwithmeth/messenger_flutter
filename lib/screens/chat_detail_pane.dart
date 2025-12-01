import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:messenger_flutter/api/accounts_service.dart';
import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/api/chats_service.dart';
import 'package:messenger_flutter/api/media_service.dart';
import 'package:messenger_flutter/api/messages_service.dart';
import 'package:messenger_flutter/api/unread_service.dart';
import 'package:messenger_flutter/models/chat_models.dart';
import 'package:messenger_flutter/config.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:messenger_flutter/widgets/media_bubbles.dart';
import 'dart:async';

/// Встраиваемая панель детального просмотра чата (без Scaffold)
class ChatDetailPane extends StatefulWidget {
  final ApiClient client;
  final ChatDto chat;
  const ChatDetailPane({super.key, required this.client, required this.chat});

  @override
  State<ChatDetailPane> createState() => _ChatDetailPaneState();
}

class _ChatDetailPaneState extends State<ChatDetailPane> {
  late final ChatsService _chats;
  late final MessagesService _messages;
  late final MediaService _media;
  late final OrganizationPhonesService _phones;
  late final UnreadService _unread;

  final _textCtrl = TextEditingController();
  final _jidCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<MessageDto> _items = [];
  List<dynamic> _orgPhones = [];
  int? _selectedPhoneId;
  bool _loading = false;
  String? _error;
  final Map<String, ImageProvider> _imageCache = {};
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _chats = ChatsService(widget.client);
    _messages = MessagesService(widget.client);
    _media = MediaService(widget.client);
    _phones = OrganizationPhonesService(widget.client);
    _unread = UnreadService(widget.client);

    // Автоподстановка данных из чата
    if (widget.chat.remoteJid != null && widget.chat.remoteJid!.isNotEmpty) {
      _jidCtrl.text = widget.chat.remoteJid!;
    }
    _selectedPhoneId = widget.chat.organizationPhoneId;

    _load();
    _loadPhones();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant ChatDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      // Обновляем авто-поля при переключении чата
      if (widget.chat.remoteJid != null && widget.chat.remoteJid!.isNotEmpty) {
        _jidCtrl.text = widget.chat.remoteJid!;
      } else {
        _jidCtrl.clear();
      }
      _selectedPhoneId = widget.chat.organizationPhoneId;
      _load();
      _loadPhones();
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    _textCtrl.dispose();
    _jidCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _absUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // Если URL начинается с /media/, проверяем, может это R2 хранилище
    if (url.startsWith('/media/')) {
      // Возвращаем полный URL с R2 хранилища
      return 'https://r2.drawbridge.kz$url';
    }
    final base = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }

  Future<void> _load({bool showLoading = true}) async {
    // Сохраняем текущую позицию скролла ДО любых изменений state
    final currentOffset = _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;
    final isAtBottom = _scrollCtrl.hasClients
        ? _scrollCtrl.offset <=
              10.0 // небольшой порог для "внизу"
        : true;
    final oldLength = _items.length;

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await _chats.chatMessages(widget.chat.id);

      setState(() {
        _items = res.messages.reversed.toList();
        if (showLoading) _loading = false;
      });

      // Восстанавливаем позицию ПОСЛЕ завершения рендеринга
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollCtrl.hasClients) return;

        // Если были внизу или это первая загрузка - остаёмся внизу
        if (isAtBottom || oldLength == 0) {
          _scrollCtrl.jumpTo(0.0);
        } else {
          // Иначе восстанавливаем сохранённую позицию
          final maxScroll = _scrollCtrl.position.maxScrollExtent;
          final targetOffset = currentOffset > maxScroll
              ? maxScroll
              : currentOffset;
          _scrollCtrl.jumpTo(targetOffset);
        }
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        if (showLoading) _loading = false;
      });
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted) return;
      if (_loading) return;
      try {
        await _load(showLoading: false); // при polling не показываем индикатор
      } catch (_) {
        // игнорируем мягко
      }
    });
  }

  Future<void> _loadPhones() async {
    try {
      final list = await _phones.all();
      setState(() {
        _orgPhones = list;
        _selectedPhoneId ??= (list.isNotEmpty
            ? (list.first['id'] as int?)
            : null);
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    if (_selectedPhoneId == null) {
      setState(() => _error = 'Выберите номер (organizationPhoneId)');
      return;
    }
    if (_jidCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Укажите receiverJid');
      return;
    }
    setState(() => _loading = true);
    try {
      await _messages.sendText(
        organizationPhoneId: _selectedPhoneId!,
        receiverJid: _jidCtrl.text.trim(),
        text: text,
      );
      _textCtrl.clear();
      await _load();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await picked.readAsBytes();
      final fileName = picked.name.isNotEmpty ? picked.name : 'upload.jpg';
      final part = MultipartFile.fromBytes(bytes, filename: fileName);
      final caption = _textCtrl.text.trim().isNotEmpty
          ? _textCtrl.text.trim()
          : null;
      await _media.uploadAndSend(
        mediaPart: part,
        chatId: widget.chat.id,
        mediaType: 'image',
        caption: caption,
      );
      if (caption != null) _textCtrl.clear();
      await _load();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      final result = await _unread.markChatRead(widget.chat.id);
      final markedCount = result['markedCount'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Отмечено как прочитано: $markedCount сообщений'),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Ошибка: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Верхняя панель
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chat.name?.isNotEmpty == true
                          ? widget.chat.name!
                          : (widget.chat.remoteJid ?? 'Чат #${widget.chat.id}'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'org: ${widget.chat.organizationPhone?.displayName ?? widget.chat.organizationPhone?.phoneJid ?? '—'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _markAsRead,
                icon: const Icon(Icons.done_all),
                tooltip: 'Отметить как прочитанное',
                color: Colors.green.shade600,
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Обновить сообщения',
              ),
            ],
          ),
        ),
        // Панель выбора orgPhone и JID
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedPhoneId,
                  items: _orgPhones
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: e['id'] as int?,
                          child: Text(
                            '${e['displayName'] ?? 'phone'} (#${e['id'] ?? ''})',
                          ),
                        ),
                      )
                      .where((e) => e.value != null)
                      .cast<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: null, // Отключаем редактирование
                  decoration: const InputDecoration(
                    labelText: 'Номер (orgPhoneId)',
                  ),
                  disabledHint: _selectedPhoneId != null
                      ? Text(
                          _orgPhones.firstWhere(
                                (e) => e['id'] == _selectedPhoneId,
                                orElse: () => {
                                  'displayName': 'phone',
                                  'id': _selectedPhoneId,
                                },
                              )['displayName'] ??
                              'phone (#$_selectedPhoneId)',
                          style: const TextStyle(color: Colors.black87),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _jidCtrl,
                  readOnly: true, // Отключаем редактирование
                  decoration: const InputDecoration(
                    labelText: 'receiverJid',
                    hintText: '7900...@s.whatsapp.net',
                  ),
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Список сообщений
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final m = _items[i];
                    final isMine = m.senderUserId != null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMine
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.65,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMine
                                    ? const Radius.circular(16)
                                    : const Radius.circular(4),
                                bottomRight: isMine
                                    ? const Radius.circular(4)
                                    : const Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  offset: const Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (m.senderJid != null || isMine)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Text(
                                      m.senderJid ?? 'Вы',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isMine
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                if (m.mediaUrl != null &&
                                    m.mediaUrl!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: _buildMediaWidget(m),
                                  ),
                                if (m.content.isNotEmpty)
                                  Text(
                                    m.content,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isMine
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      m.timestamp
                                          .toLocal()
                                          .toString()
                                          .substring(11, 16),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            (isMine
                                                    ? Theme.of(context)
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant)
                                                .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        // Поле ввода
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, -1),
                blurRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _loading ? null : _sendImage,
                  icon: Icon(
                    Icons.image_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  tooltip: 'Отправить изображение',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _textCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Сообщение...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendText(),
                    maxLines: null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _loading ? null : _sendText,
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  tooltip: 'Отправить',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaWidget(MessageDto m) {
    final url = _absUrl(m.mediaUrl!);
    if (m.type == 'image') {
      final cached = _imageCache[url];
      final img = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 360),
          child: cached != null
              ? Image(image: cached, fit: BoxFit.cover)
              : FutureBuilder(
                  future: widget.client.getBytes(url),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        width: 80,
                        height: 80,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    if (snap.hasError || !snap.hasData) {
                      return _mediaFallback(url, m.type);
                    }
                    final bytes = snap.data!;
                    final provider = MemoryImage(bytes);
                    _imageCache[url] = provider;
                    return Image.memory(bytes, fit: BoxFit.cover);
                  },
                ),
        ),
      );
      return img;
    }
    if (m.type == 'video') {
      return VideoBubble(client: widget.client, url: url);
    }
    if (m.type == 'audio') {
      return AudioBubble(client: widget.client, url: url);
    }
    return _mediaFallback(url, m.type);
  }

  Widget _mediaFallback(String url, String type) {
    final fileName = Uri.tryParse(url)?.pathSegments.isNotEmpty == true
        ? Uri.parse(url).pathSegments.last
        : url;
    return InkWell(
      onLongPress: () => Clipboard.setData(ClipboardData(text: url)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text('$type: $fileName', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
