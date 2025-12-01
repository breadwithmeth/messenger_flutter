import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/api/chats_service.dart';
import 'package:messenger_flutter/api/unread_service.dart';
import 'package:messenger_flutter/models/chat_models.dart';
import 'package:messenger_flutter/screens/messages_page.dart';
import 'dart:async';

class AssignedChatsPage extends StatefulWidget {
  final ApiClient client;

  const AssignedChatsPage({super.key, required this.client});

  @override
  State<AssignedChatsPage> createState() => _AssignedChatsPageState();
}

class _AssignedChatsPageState extends State<AssignedChatsPage> {
  late final ChatsService _chats;
  late final UnreadService _unread;
  List<ChatDto> _items = [];
  bool _loading = false;
  String? _error;
  ChatDto? _selectedChat;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _chats = ChatsService(widget.client);
    _unread = UnreadService(widget.client);
    _loadChats();
    _startPolling();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poller = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadChats();
    });
  }

  Future<void> _loadChats() async {
    try {
      // Загружаем только назначенные чаты
      final resp = await _chats.listChats(
        filters: ChatFilters(assigned: true, includeProfile: true),
        sortBy: 'lastMessageAt',
        sortOrder: 'desc',
      );

      if (mounted) {
        setState(() {
          _items = resp.chats;
          _error = null;

          if (_selectedChat != null) {
            final selId = _selectedChat!.id;
            final idx = _items.indexWhere((e) => e.id == selId);
            _selectedChat = idx >= 0 ? _items[idx] : null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final unreadChats = _items.where((c) => c.unreadCount > 0).toList();
    if (unreadChats.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нет непрочитанных чатов')));
      return;
    }

    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Пометить все как прочитанные?'),
          content: Text(
            'Будет отмечено ${unreadChats.length} чат(ов) как прочитанные',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Пометить'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _loading = true);

      for (final chat in unreadChats) {
        try {
          await _unread.markChatRead(chat.id);
        } catch (e) {
          // Игнорируем ошибки для отдельных чатов
        }
      }

      await _loadChats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Отмечено ${unreadChats.length} чат(ов)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _loadChats,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2,
              size: 64,
              color: CupertinoColors.systemGrey.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет назначенных чатов',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Назначенные вам чаты появятся здесь',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, idx) {
        final chat = _items[idx];
        final isSelected = _selectedChat?.id == chat.id;
        final hasUnread = chat.unreadCount > 0;

        return Container(
          decoration: BoxDecoration(
            color: isSelected
                ? CupertinoColors.systemGrey5.resolveFrom(context)
                : null,
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
          ),
          child: CupertinoListTile(
            onTap: () {
              setState(() => _selectedChat = chat);
              Navigator.of(context)
                  .push(
                    CupertinoPageRoute(
                      builder: (_) => MessagesPage(
                        client: widget.client,
                        chatId: chat.id,
                        initialReceiverJid: chat.remoteJid,
                        initialOrganizationPhoneId: chat.organizationPhoneId,
                        chat: chat,
                      ),
                    ),
                  )
                  .then((_) => _loadChats());
            },
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
              child: Center(
                child: Icon(
                  chat.isTelegram
                      ? CupertinoIcons.chat_bubble_text_fill
                      : CupertinoIcons.chat_bubble_2_fill,
                  color: chat.isTelegram
                      ? CupertinoColors.activeBlue.resolveFrom(context)
                      : CupertinoColors.systemGreen.resolveFrom(context),
                  size: 24,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    chat.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (chat.lastMessageAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(chat.lastMessageAt!),
                    style: TextStyle(
                      fontSize: 13,
                      color: hasUnread
                          ? CupertinoColors.activeBlue.resolveFrom(context)
                          : CupertinoColors.secondaryLabel.resolveFrom(context),
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    chat.lastMessage?.content ?? 'Нет сообщений',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${chat.unreadCount}',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            additionalInfo: chat.assignedUser != null
                ? Text(
                    '👤 ${chat.assignedUser!.name ?? chat.assignedUser!.email ?? 'ID: ${chat.assignedUser!.id}'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGreen.resolveFrom(context),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
    if (diff.inHours < 24) return '${diff.inHours} ч';
    if (diff.inDays < 7) return '${diff.inDays} д';

    return '${time.day}.${time.month}';
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
            Icon(
              CupertinoIcons.person_crop_circle_fill_badge_checkmark,
              color: CupertinoColors.systemGreen.resolveFrom(context),
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              'Назначенные чаты',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _markAllAsRead,
              child: Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                color: _items.any((c) => c.unreadCount > 0)
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.systemGrey,
                size: 28,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadChats,
              child: const Icon(CupertinoIcons.refresh, size: 28),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }
}
