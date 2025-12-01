import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/api/chats_service.dart';
import 'package:messenger_flutter/api/messages_service.dart';
import 'package:messenger_flutter/api/media_service.dart';
import 'package:messenger_flutter/api/accounts_service.dart';
import 'package:messenger_flutter/api/unread_service.dart';
import 'package:messenger_flutter/api/telegram_bots_service.dart';
import 'package:messenger_flutter/api/auth_service.dart';
import 'package:messenger_flutter/api/chat_assignment_service.dart';
import 'package:messenger_flutter/models/auth_models.dart';
import 'package:messenger_flutter/models/chat_models.dart';
import 'package:messenger_flutter/config.dart';
import 'package:messenger_flutter/api/ollama_service.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:messenger_flutter/widgets/media_bubbles.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'dart:async';

class MessagesPage extends StatefulWidget {
  final ApiClient client;
  final int chatId;
  final String? initialReceiverJid;
  final int? initialOrganizationPhoneId;
  final ChatDto? chat; // Добавляем возможность передать объект чата

  const MessagesPage({
    super.key,
    required this.client,
    required this.chatId,
    this.initialReceiverJid,
    this.initialOrganizationPhoneId,
    this.chat, // Опциональный параметр
  });

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late final ChatsService _chats;
  late final MessagesService _messages;
  late final MediaService _media;
  late final OrganizationPhonesService _phones;
  late final UnreadService _unread;
  late final TelegramBotsService _telegramBots;
  late final AuthService _auth;
  late final ChatAssignmentService _chatAssignment;
  final _textCtrl = TextEditingController();
  UserDto? _me;
  final _scrollCtrl = ScrollController();
  final _jidCtrl = TextEditingController();
  List<MessageDto> _items = [];
  bool _loading = false;
  bool _sending = false;
  String? _error;
  List<dynamic> _orgPhones = [];
  int? _selectedPhoneId;
  final Map<String, ImageProvider> _imageCache = {};
  Timer? _poller;
  List<dynamic> _operators = [];
  ChatDto? _currentChat; // Информация о текущем чате
  final _ollamaService = OllamaService();
  bool _isImprovingText = false;

  @override
  void initState() {
    super.initState();
    _chats = ChatsService(widget.client);
    _messages = MessagesService(widget.client);
    _media = MediaService(widget.client);
    _phones = OrganizationPhonesService(widget.client);
    _unread = UnreadService(widget.client);
    _telegramBots = TelegramBotsService(widget.client);
    _auth = AuthService(widget.client);
    _chatAssignment = ChatAssignmentService(widget.client);
    _loadCurrentUser();

    // Если чат передан напрямую, используем его
    if (widget.chat != null) {
      _currentChat = widget.chat;
      print('DEBUG: Chat provided directly: ${_currentChat?.channel}');
    } else {
      _loadChatInfo();
    }

    _load();
    _loadPhones();
    _loadOperators();
    _startPolling();
    // Автоподстановка из чата
    if (widget.initialReceiverJid != null &&
        widget.initialReceiverJid!.isNotEmpty) {
      _jidCtrl.text = widget.initialReceiverJid!;
    }
    if (widget.initialOrganizationPhoneId != null) {
      _selectedPhoneId = widget.initialOrganizationPhoneId;
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _jidCtrl.dispose();
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
      // Если chatId = 0, это новый чат - не загружаем сообщения
      if (widget.chatId == 0) {
        setState(() {
          _items = [];
          if (showLoading) _loading = false;
        });
        return;
      }

      // Используем новый API endpoint с поддержкой пагинации
      final res = await _messages.getMessages(
        chatId: widget.chatId,
        limit: 100, // По умолчанию последние 100 сообщений
      );

      setState(() {
        final messages =
            (res['messages'] as List?)
                ?.map((e) => MessageDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        _items = messages.reversed.toList();
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
      } catch (_) {}
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
    } catch (e) {
      // игнорируем мягко; отправка текста просто потребует выбора
    }
  }

  Future<void> _loadOperators() async {
    try {
      final list = await _chats.getOperators();
      setState(() {
        _operators = list;
      });
    } catch (e) {
      // игнорируем мягко
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _auth.me();
      setState(() {
        _me = user;
      });
    } catch (e) {
      // игнорируем мягко
    }
  }

  Future<void> _loadChatInfo() async {
    if (widget.chatId == 0) return; // Новый чат

    try {
      print('DEBUG: Loading chat info for chatId: ${widget.chatId}');
      // Загружаем информацию о чате из списка чатов
      final chatsResponse = await _chats.listChats();
      print('DEBUG: Got ${chatsResponse.chats.length} chats from API');

      final chat = chatsResponse.chats.firstWhere(
        (c) => c.id == widget.chatId,
        orElse: () => throw Exception('Chat not found'),
      );

      print(
        'DEBUG: Found chat: id=${chat.id}, channel=${chat.channel}, isTelegram=${chat.isTelegram}',
      );
      print(
        'DEBUG: Telegram bot: ${chat.telegramBot?.id}, chatId: ${chat.telegramChatId}',
      );

      setState(() {
        _currentChat = chat;
      });
    } catch (e) {
      // Игнорируем ошибки, будем использовать WhatsApp по умолчанию
      print('Error loading chat info: $e');
    }
  }

  Future<void> _assignChatToMe() async {
    if (widget.chatId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Нельзя назначить новый чат. Сначала отправьте сообщение.',
          ),
          backgroundColor: CupertinoColors.destructiveRed,
        ),
      );
      return;
    }

    if (_me == null) {
      await _loadCurrentUser();
    }

    if (_me == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось определить текущего пользователя'),
            backgroundColor: CupertinoColors.destructiveRed,
          ),
        );
      }
      return;
    }

    try {
      await _chats.assignChat(widget.chatId, _me!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Чат назначен вам (${_me!.email})'),
            backgroundColor: CupertinoColors.systemGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка назначения: $e'),
            backgroundColor: CupertinoColors.destructiveRed,
          ),
        );
      }
    }
  }

  Future<void> _unassignChat() async {
    if (widget.chatId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя снять назначение с нового чата.'),
          backgroundColor: CupertinoColors.destructiveRed,
        ),
      );
      return;
    }

    // Показываем диалог подтверждения
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Снять назначение'),
        content: const Text(
          'Вы уверены, что хотите снять назначение с этого чата?',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Снять назначение'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _chatAssignment.unassign(chatId: widget.chatId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Назначение снято'),
            backgroundColor: CupertinoColors.systemGreen,
          ),
        );
        // Обновляем информацию о чате
        await _loadChatInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка снятия назначения: $e'),
            backgroundColor: CupertinoColors.destructiveRed,
          ),
        );
      }
    }
  }

  Future<void> _assignChatToOperator() async {
    if (widget.chatId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Нельзя назначить новый чат. Сначала отправьте сообщение.',
          ),
          backgroundColor: CupertinoColors.destructiveRed,
        ),
      );
      return;
    }

    if (_operators.isEmpty) {
      await _loadOperators();
    }

    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Назначить чат оператору'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ..._operators.map((op) {
              final name = op['name'] ?? op['email'] ?? 'ID: ${op['id']}';
              return CupertinoDialogAction(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _chats.assignChat(widget.chatId, op['id'] as int);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Чат назначен оператору: $name'),
                          backgroundColor: CupertinoColors.systemGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ошибка назначения: $e'),
                          backgroundColor: CupertinoColors.destructiveRed,
                        ),
                      );
                    }
                  }
                },
                child: Text(name),
              );
            }).toList(),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePriority() async {
    if (widget.chatId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя изменить приоритет нового чата'),
          backgroundColor: CupertinoColors.destructiveRed,
        ),
      );
      return;
    }

    final priorities = ['low', 'normal', 'high', 'urgent'];
    final priorityLabels = {
      'low': 'Низкий',
      'normal': 'Обычный',
      'high': 'Высокий',
      'urgent': 'Срочный',
    };

    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Изменить приоритет'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ...priorities.map((priority) {
              return CupertinoDialogAction(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final result = await _chats.changePriority(
                      chatId: widget.chatId,
                      priority: priority,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result['message'] ??
                                'Приоритет изменен на ${priorityLabels[priority]}',
                          ),
                          backgroundColor: CupertinoColors.systemGreen,
                        ),
                      );
                      // Обновляем информацию о чате
                      _loadChatInfo();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ошибка изменения приоритета: $e'),
                          backgroundColor: CupertinoColors.destructiveRed,
                        ),
                      );
                    }
                  }
                },
                child: Text(priorityLabels[priority]!),
              );
            }).toList(),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeChat() async {
    if (widget.chatId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя закрыть новый чат'),
          backgroundColor: CupertinoColors.destructiveRed,
        ),
      );
      return;
    }

    final reasonCtrl = TextEditingController();

    if (!mounted) return;

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Закрыть чат?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Чат будет помечен как закрытый'),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: reasonCtrl,
              placeholder: 'Причина закрытия (необязательно)',
              maxLines: 3,
              padding: const EdgeInsets.all(12),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Закрыть чат'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _chats.closeChat(
        chatId: widget.chatId,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Чат закрыт'),
            backgroundColor: CupertinoColors.systemGreen,
          ),
        );
        // Обновляем информацию о чате
        _loadChatInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка закрытия чата: $e'),
            backgroundColor: CupertinoColors.destructiveRed,
          ),
        );
      }
    }
  }

  /// Удаляет теги <think>...</think> из текста
  String _removeThinkTags(String text) {
    // Удаляем все вхождения <think>...</think> (включая многострочные)
    return text
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .trim();
  }

  Future<void> _improveText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    // Проверяем, включена ли Ollama
    final isEnabled = await AppConfig.isOllamaEnabled();
    if (!isEnabled) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Ollama не настроена'),
          content: const Text(
            'Для улучшения текста необходимо настроить Ollama в настройках приложения.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isImprovingText = true);
    try {
      final prompt =
          '''Перепиши текст вежливо и профессионально. Поменяй местами предложения, улучши стиль и грамматику, сохрани смысл.

Текст: $text

''';

      final improvedText = await _ollamaService.generate(prompt: prompt);

      if (!mounted) return;

      if (improvedText != null && improvedText.trim().isNotEmpty) {
        // Удаляем теги <think> из ответа
        final cleanedText = _removeThinkTags(improvedText);

        setState(() {
          _textCtrl.text = cleanedText;
        });

        // Показываем уведомление об успехе
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Текст улучшен!'),
            backgroundColor: CupertinoColors.systemGreen.resolveFrom(context),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Не удалось получить улучшенный текст');
      }
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Ошибка'),
          content: Text(
            'Не удалось улучшить текст: $e\n\nПроверьте настройки Ollama и убедитесь, что сервер запущен.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImprovingText = false);
      }
    }
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      // Проверяем тип чата
      print('DEBUG: Sending message, _currentChat: ${_currentChat?.channel}');
      print('DEBUG: isTelegram: ${_currentChat?.isTelegram}');

      if (_currentChat?.isTelegram == true) {
        // Отправка через Telegram API
        final botId = _currentChat!.telegramBot?.id;
        final telegramChatId = _currentChat!.telegramChatId;

        print('DEBUG: Telegram botId: $botId, chatId: $telegramChatId');

        if (botId == null || telegramChatId == null) {
          setState(() => _error = 'Telegram bot or chat ID not found');
          return;
        }

        print('DEBUG: Sending Telegram message: $text');
        await _telegramBots.sendMessage(
          botId: botId,
          chatId: telegramChatId,
          content: text,
        );
        print('DEBUG: Telegram message sent successfully');
      } else {
        // Отправка через WhatsApp API
        print('DEBUG: Sending WhatsApp message');
        if (_selectedPhoneId == null) {
          setState(() => _error = 'Выберите номер (organizationPhoneId)');
          return;
        }
        if (_jidCtrl.text.trim().isEmpty) {
          setState(() => _error = 'Укажите receiverJid');
          return;
        }

        await _messages.sendText(
          organizationPhoneId: _selectedPhoneId!,
          receiverJid: _jidCtrl.text.trim(),
          text: text,
        );
      }

      _textCtrl.clear();
      await _load();
    } catch (e) {
      print('DEBUG: Error sending message: $e');
      setState(() => _error = '$e');
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final bytes = await picked.readAsBytes();
      final fileName = picked.name.isNotEmpty ? picked.name : 'upload.jpg';
      await _showImagePreview(bytes, fileName);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _sendDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось прочитать файл'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await _showDocumentPreview(file.bytes!, file.name);
  }

  Future<void> _showDocumentPreview(Uint8List bytes, String fileName) async {
    if (!mounted) return;

    final shouldSend = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Отправить документ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Icon(
              CupertinoIcons.doc_fill,
              size: 64,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 12),
            Text(
              fileName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${(bytes.length / 1024).toStringAsFixed(1)} KB',
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );

    if (shouldSend == true && mounted) {
      setState(() => _sending = true);
      try {
        await _uploadAndSendDocument(bytes, fileName);
      } finally {
        if (mounted) {
          setState(() => _sending = false);
        }
      }
    }
  }

  Future<void> _uploadAndSendDocument(Uint8List bytes, String fileName) async {
    final part = MultipartFile.fromBytes(bytes, filename: fileName);

    final caption = _textCtrl.text.trim().isNotEmpty
        ? _textCtrl.text.trim()
        : null;

    await _media.uploadAndSend(
      mediaPart: part,
      chatId: widget.chatId,
      mediaType: 'document',
      caption: caption,
    );

    if (caption != null) _textCtrl.clear();
    await _load();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Документ отправлен'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Буфер обмена недоступен на этой платформе'),
            ),
          );
        }
        return;
      }

      final reader = await clipboard.read();

      // Проверяем каждый элемент в буфере обмена
      for (var item in reader.items) {
        // Пробуем получить изображение PNG
        if (item.canProvide(Formats.png)) {
          try {
            item.getFile(Formats.png, (file) async {
              try {
                final stream = file.getStream();
                final bytes = await stream.toList();
                final imageBytes = Uint8List.fromList(
                  bytes.expand((x) => x).toList(),
                );
                await _showImagePreview(imageBytes, 'pasted_image.png');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка при чтении изображения: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка при обработке изображения: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          return;
        }

        // Пробуем получить изображение JPEG
        if (item.canProvide(Formats.jpeg)) {
          try {
            item.getFile(Formats.jpeg, (file) async {
              try {
                final stream = file.getStream();
                final bytes = await stream.toList();
                final imageBytes = Uint8List.fromList(
                  bytes.expand((x) => x).toList(),
                );
                await _showImagePreview(imageBytes, 'pasted_image.jpg');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка при чтении изображения: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка при обработке изображения: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          return;
        }

        // Пробуем получить изображение GIF
        if (item.canProvide(Formats.gif)) {
          try {
            item.getFile(Formats.gif, (file) async {
              try {
                final stream = file.getStream();
                final bytes = await stream.toList();
                final imageBytes = Uint8List.fromList(
                  bytes.expand((x) => x).toList(),
                );
                await _showImagePreview(imageBytes, 'pasted_image.gif');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка при чтении изображения: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка при обработке изображения: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          return;
        }
      }

      // Если изображение не найдено, пробуем вставить текст
      for (var item in reader.items) {
        if (item.canProvide(Formats.plainText)) {
          try {
            final text = await item.readValue(Formats.plainText);
            if (text != null) {
              setState(() {
                _textCtrl.text += text;
              });
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ошибка вставки текста: $e')),
              );
            }
          }
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка доступа к буферу обмена: $e')),
        );
      }
    }
  }

  // Показывает превью изображения перед отправкой
  Future<void> _showImagePreview(Uint8List bytes, String fileName) async {
    if (!mounted) return;

    final shouldSend = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final maxImageHeight = screenHeight * 0.5; // 50% высоты экрана
        final maxImageWidth = screenWidth * 0.7; // 70% ширины экрана

        return CupertinoAlertDialog(
          title: const Text('Отправить изображение?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxImageWidth,
                      maxHeight: maxImageHeight,
                    ),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.systemGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(bytes.length / 1024).toStringAsFixed(1)} KB',
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Отправить'),
            ),
          ],
        );
      },
    );

    if (shouldSend == true && mounted) {
      setState(() => _sending = true);
      try {
        await _uploadAndSendImage(bytes, fileName);
      } finally {
        if (mounted) {
          setState(() => _sending = false);
        }
      }
    }
  }

  Future<void> _uploadAndSendImage(Uint8List bytes, String fileName) async {
    final part = MultipartFile.fromBytes(bytes, filename: fileName);

    final caption = _textCtrl.text.trim().isNotEmpty
        ? _textCtrl.text.trim()
        : null;

    await _media.uploadAndSend(
      mediaPart: part,
      chatId: widget.chatId,
      mediaType: 'image',
      caption: caption,
    );

    if (caption != null) _textCtrl.clear();
    await _load();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Изображение отправлено'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _markAsRead() async {
    try {
      final result = await _unread.markChatRead(widget.chatId);
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
    return Scaffold(
      appBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, size: 28),
        ),
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
              child: Icon(
                CupertinoIcons.person_fill,
                color: CupertinoColors.systemGrey.resolveFrom(context),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentChat?.isTelegram == true) ...[
                        Icon(
                          CupertinoIcons.chat_bubble_text_fill,
                          size: 14,
                          color: CupertinoColors.activeBlue.resolveFrom(
                            context,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        widget.chatId == 0
                            ? 'Новый чат'
                            : (_currentChat?.displayName ??
                                  'Чат #${widget.chatId}'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _items.isEmpty
                        ? 'Нет сообщений'
                        : '${_items.length} сообщений',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Быстрая кнопка "Назначить мне"
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _assignChatToMe,
              child: const Icon(
                CupertinoIcons.person_fill,
                color: CupertinoColors.activeBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 8),
            // Быстрая кнопка "Снять назначение"
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _unassignChat,
              child: const Icon(
                CupertinoIcons.person_badge_minus,
                color: CupertinoColors.systemOrange,
                size: 28,
              ),
            ),
            const SizedBox(width: 8),
            // Меню с дополнительными действиями
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => CupertinoActionSheet(
                    title: const Text('Действия с чатом'),
                    actions: [
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Navigator.pop(context);
                          _assignChatToOperator();
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.person_2_fill, size: 20),
                            SizedBox(width: 8),
                            Text('Назначить оператору'),
                          ],
                        ),
                      ),
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Navigator.pop(context);
                          _changePriority();
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.flag_fill, size: 20),
                            SizedBox(width: 8),
                            Text('Изменить приоритет'),
                          ],
                        ),
                      ),
                      CupertinoActionSheetAction(
                        isDestructiveAction: true,
                        onPressed: () {
                          Navigator.pop(context);
                          _closeChat();
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.lock_fill, size: 20),
                            SizedBox(width: 8),
                            Text('Закрыть чат'),
                          ],
                        ),
                      ),
                    ],
                    cancelButton: CupertinoActionSheetAction(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                  ),
                );
              },
              child: const Icon(
                CupertinoIcons.ellipsis_circle_fill,
                color: CupertinoColors.activeBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _markAsRead,
              child: Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                color: CupertinoColors.systemGreen.resolveFrom(context),
                size: 28,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Панель выбора телефона и JID для отправки текста (только для WhatsApp)
          if (_currentChat?.isWhatsApp !=
              false) // Показываем для WhatsApp или если чат еще не загружен
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
                      // Сообщение от оператора если есть senderUser
                      final isMine = m.senderUser != null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: isMine
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMine) ...[
                              Container(
                                margin: const EdgeInsets.only(
                                  right: 8,
                                  bottom: 4,
                                ),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: CupertinoColors.systemGrey5
                                      .resolveFrom(context),
                                ),
                                child: Icon(
                                  CupertinoIcons.person_fill,
                                  color: CupertinoColors.systemGrey.resolveFrom(
                                    context,
                                  ),
                                  size: 16,
                                ),
                              ),
                            ],
                            Flexible(
                              child: GestureDetector(
                                onLongPress: () {
                                  if (m.content.isNotEmpty) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Действия'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.copy),
                                              title: const Text(
                                                'Копировать текст',
                                              ),
                                              onTap: () {
                                                Clipboard.setData(
                                                  ClipboardData(
                                                    text: m.content,
                                                  ),
                                                );
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Текст скопирован',
                                                    ),
                                                    duration: Duration(
                                                      seconds: 1,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Закрыть'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? CupertinoColors.activeBlue
                                              .resolveFrom(context)
                                        : CupertinoColors.systemGrey5
                                              .resolveFrom(context),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft: isMine
                                          ? const Radius.circular(20)
                                          : const Radius.circular(4),
                                      bottomRight: isMine
                                          ? const Radius.circular(4)
                                          : const Radius.circular(20),
                                    ),
                                  ),
                                  child: IntrinsicWidth(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (m.senderJid != null || isMine)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6.0,
                                            ),
                                            child: Text(
                                              isMine
                                                  ? (m.senderUser?.name ??
                                                        m.senderUser?.email ??
                                                        'Оператор')
                                                  : (m.senderJid ?? 'Клиент'),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isMine
                                                    ? CupertinoColors.white
                                                    : CupertinoColors
                                                          .activeBlue,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (m.mediaUrl != null &&
                                            m.mediaUrl!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8.0,
                                            ),
                                            child: _buildMediaWidget(m),
                                          ),
                                        if (m.content.isNotEmpty)
                                          SelectableText(
                                            m.content,
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 1.4,
                                              color: isMine
                                                  ? CupertinoColors.white
                                                  : CupertinoColors.label
                                                        .resolveFrom(context),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.tag_faces_rounded,
                                              size: 12,
                                              color: isMine
                                                  ? CupertinoColors.white
                                                        .withOpacity(0.7)
                                                  : CupertinoColors
                                                        .secondaryLabel
                                                        .resolveFrom(context),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              m.timestamp
                                                  .toLocal()
                                                  .toString()
                                                  .substring(11, 16),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: isMine
                                                    ? CupertinoColors.white
                                                          .withOpacity(0.8)
                                                    : CupertinoColors
                                                          .secondaryLabel
                                                          .resolveFrom(context),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ), // Column
                                  ), // IntrinsicWidth
                                ), // Container
                              ), // GestureDetector
                            ), // Flexible
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemRed
                    .resolveFrom(context)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CupertinoColors.systemRed
                      .resolveFrom(context)
                      .withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: CupertinoColors.systemRed.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              border: Border(
                top: BorderSide(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _sending ? null : _sendImage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      CupertinoIcons.photo,
                      color: CupertinoColors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _sending ? null : _sendDocument,
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed.resolveFrom(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      CupertinoIcons.doc_fill,
                      color: CupertinoColors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: CupertinoColors.separator.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                    child: Focus(
                      onKeyEvent: (node, event) {
                        // Обработка Enter (отправка) и Shift+Enter (новая строка)
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          // Shift+Enter - новая строка (игнорируем, даём стандартное поведение)
                          if (HardwareKeyboard.instance.isShiftPressed) {
                            return KeyEventResult.ignored;
                          }
                          // Enter без Shift - отправка сообщения
                          if (_textCtrl.text.trim().isNotEmpty) {
                            _sendText();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.handled;
                        }

                        // Ctrl+V или Cmd+V для вставки
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.keyV &&
                              (HardwareKeyboard.instance.isControlPressed ||
                                  HardwareKeyboard.instance.isMetaPressed)) {
                            _pasteFromClipboard();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: CupertinoTextField(
                        controller: _textCtrl,
                        placeholder:
                            'Сообщение... (Enter - отправить, Shift+Enter - новая строка)',
                        placeholderStyle: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                        decoration: null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        onSubmitted: (text) {
                          // Enter без Shift отправляет сообщение
                          if (text.trim().isNotEmpty) {
                            _sendText();
                          }
                        },
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Кнопка улучшения текста с помощью AI
                Tooltip(
                  message:
                      'Улучшить текст с помощью AI (дружелюбно-формальный стиль)',
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed:
                        (_loading ||
                            _isImprovingText ||
                            _textCtrl.text.trim().isEmpty)
                        ? null
                        : _improveText,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isImprovingText
                            ? CupertinoColors.systemGrey.resolveFrom(context)
                            : CupertinoColors.systemPurple.resolveFrom(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: _isImprovingText
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              ),
                            )
                          : Icon(
                              CupertinoIcons.sparkles,
                              color: CupertinoColors.white,
                              size: 24,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _sending ? null : _sendText,
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      CupertinoIcons.paperplane_fill,
                      color: CupertinoColors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaWidget(MessageDto m) {
    final url = _absUrl(m.mediaUrl!);
    if (m.type == 'image') {
      final cached = _imageCache[url];
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 360),
          child: cached != null
              ? Image(image: cached, fit: BoxFit.cover)
              : _ImageWithRetry(
                  client: widget.client,
                  url: url,
                  onCached: (provider) {
                    _imageCache[url] = provider;
                  },
                ),
        ),
      );
    }
    if (m.type == 'video') {
      return VideoBubble(client: widget.client, url: url);
    }
    if (m.type == 'audio') {
      return AudioBubble(client: widget.client, url: url);
    }
    if (m.type == 'document') {
      return _buildDocumentWidget(url);
    }
    return _mediaFallback(url, m.type);
  }

  Widget _buildDocumentWidget(String url) {
    final fileName = Uri.tryParse(url)?.pathSegments.isNotEmpty == true
        ? Uri.parse(url).pathSegments.last
        : 'document.pdf';

    return GestureDetector(
      onTap: () => _openDocument(url),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CupertinoColors.systemGrey4, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.doc_fill,
              color: CupertinoColors.systemRed,
              size: 32,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Нажмите для открытия',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось открыть документ'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка открытия документа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _mediaFallback(String url, String type) {
    final fileName = Uri.tryParse(url)?.pathSegments.isNotEmpty == true
        ? Uri.parse(url).pathSegments.last
        : url;
    return GestureDetector(
      onLongPress: () => Clipboard.setData(ClipboardData(text: url)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.paperclip, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text('$type: $fileName', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// Виджет для загрузки изображения с повторными попытками
class _ImageWithRetry extends StatefulWidget {
  final dynamic client;
  final String url;
  final Function(MemoryImage) onCached;

  const _ImageWithRetry({
    required this.client,
    required this.url,
    required this.onCached,
  });

  @override
  State<_ImageWithRetry> createState() => _ImageWithRetryState();
}

class _ImageWithRetryState extends State<_ImageWithRetry> {
  int _attemptCount = 0;
  static const int _maxAttempts = 3;
  bool _loading = true;
  String? _error;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (_attemptCount >= _maxAttempts) {
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить изображение';
      });
      return;
    }

    _attemptCount++;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = await widget.client.getBytes(widget.url);
      if (mounted) {
        final provider = MemoryImage(bytes);
        widget.onCached(provider);
        setState(() {
          _imageBytes = bytes;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        if (_attemptCount < _maxAttempts) {
          // Повторная попытка через небольшую задержку
          await Future.delayed(Duration(milliseconds: 500 * _attemptCount));
          if (mounted) {
            _loadImage();
          }
        } else {
          setState(() {
            _loading = false;
            _error = 'Не удалось загрузить изображение';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              if (_attemptCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Попытка $_attemptCount/$_maxAttempts',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              'Изображение отправлено,\nне удалось отобразить',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _attemptCount = 0;
                _loadImage();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Повторить'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Image.memory(_imageBytes!, fit: BoxFit.cover);
  }
}
