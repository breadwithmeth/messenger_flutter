import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/api/chats_service.dart';
import 'package:messenger_flutter/api/messages_service.dart';
import 'package:messenger_flutter/api/media_service.dart';
import 'package:messenger_flutter/api/accounts_service.dart';
import 'package:messenger_flutter/models/chat_models.dart';
import 'package:messenger_flutter/config.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

class MessagesPage extends StatefulWidget {
  final ApiClient client;
  final int chatId;
  final String? initialReceiverJid;
  final int? initialOrganizationPhoneId;
  const MessagesPage({
    super.key,
    required this.client,
    required this.chatId,
    this.initialReceiverJid,
    this.initialOrganizationPhoneId,
  });

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late final ChatsService _chats;
  late final MessagesService _messages;
  late final MediaService _media;
  late final OrganizationPhonesService _phones;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _jidCtrl = TextEditingController();
  List<MessageDto> _items = [];
  bool _loading = false;
  String? _error;
  List<dynamic> _orgPhones = [];
  int? _selectedPhoneId;
  final Map<String, ImageProvider> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _chats = ChatsService(widget.client);
    _messages = MessagesService(widget.client);
    _media = MediaService(widget.client);
    _phones = OrganizationPhonesService(widget.client);
    _load();
    _loadPhones();
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
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _jidCtrl.dispose();
    super.dispose();
  }

  String _absUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _chats.chatMessages(widget.chatId);
      setState(() => _items = res.messages);
      await Future.delayed(const Duration(milliseconds: 50));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
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
        chatId: widget.chatId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Чат #${widget.chatId}')),
      body: Column(
        children: [
          // Панель выбора телефона и JID для отправки текста
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
                    onChanged: (v) => setState(() => _selectedPhoneId = v),
                    decoration: const InputDecoration(
                      labelText: 'Номер (orgPhoneId)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _jidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'receiverJid',
                      hintText: '7900...@s.whatsapp.net',
                    ),
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
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final m = _items[i];
                      final isMine =
                          m.senderUserId !=
                          null; // упрощение: если есть senderUserId, считаем исходящим
                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Colors.teal.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m.senderJid != null || isMine)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2.0),
                                  child: Text(
                                    m.senderJid ?? 'Вы',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              if (m.mediaUrl != null && m.mediaUrl!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: _buildMediaWidget(m),
                                ),
                              Text(m.content.isEmpty ? '...' : m.content),
                              const SizedBox(height: 4),
                              Text(
                                m.timestamp.toLocal().toString().substring(
                                  0,
                                  19,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _loading ? null : _sendImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: const InputDecoration(hintText: 'Сообщение...'),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _sendText,
                  icon: const Icon(Icons.send),
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
