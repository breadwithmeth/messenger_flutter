import 'package:flutter/material.dart';
import 'api/api_client.dart';
import 'api/auth_service.dart';
import 'api/chats_service.dart';
import 'models/chat_models.dart';
import 'config.dart';
import 'screens/login_page.dart';
import 'screens/organizations_page.dart';
import 'screens/users_page.dart';
import 'screens/phones_page.dart';
import 'screens/unread_page.dart';
import 'screens/messages_page.dart';
import 'screens/wa_page.dart';
import 'api/chat_assignment_service.dart';
import 'models/auth_models.dart';
import 'screens/chat_detail_pane.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Messenger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const MyHomePage(title: 'Чаты'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final ApiClient _client;
  late final AuthService _auth;
  late final ChatsService _chats;
  late final ChatAssignmentService _assign;
  List<ChatDto> _items = [];
  bool _loading = false;
  String? _error;
  UserDto? _me;
  ChatDto? _selectedChat;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(baseUrl: AppConfig.baseUrl);
    _auth = AuthService(_client);
    _chats = ChatsService(_client);
    _assign = ChatAssignmentService(_client);
    _bootstrap();
    _startPolling();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _client.getToken();
      if (token == null || token.isEmpty) {
        // Если токена нет - перенаправляем на страницу входа
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _openLogin());
        return;
      }
      // Получим текущего пользователя для operatorId при назначении
      _me = await _auth.me();
      await _loadChats();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _assignToMe(ChatDto c) async {
    if (_me == null) return;
    setState(() => _loading = true);
    try {
      await _assign.assign(chatId: c.id, operatorId: _me!.id);
      await _loadChats();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _unassignChat(ChatDto c) async {
    setState(() => _loading = true);
    try {
      await _assign.unassign(chatId: c.id);
      await _loadChats();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _setPriority(ChatDto c, String p) async {
    setState(() => _loading = true);
    try {
      await _assign.setPriority(chatId: c.id, priority: p);
      await _loadChats();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _closeChat(ChatDto c) async {
    setState(() => _loading = true);
    try {
      await _assign.close(chatId: c.id);
      await _loadChats();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadChats() async {
    final resp = await _chats.listChats();
    setState(() {
      _items = resp.chats;
      if (_selectedChat != null) {
        final selId = _selectedChat!.id;
        final idx = _items.indexWhere((e) => e.id == selId);
        _selectedChat = idx >= 0 ? _items[idx] : null;
      }
    });
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      if (_loading) return;
      try {
        await _loadChats();
      } catch (_) {
        // мягко игнорируем ошибки опроса
      }
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _openLogin() async {
    final success = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => LoginPage(auth: _auth)));
    if (success == true) {
      _me = await _auth.me();
      await _loadChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Row(
          children: [
            Icon(Icons.chat, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(widget.title),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChats,
            tooltip: 'Обновить',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _me?.email ?? 'Мессенджер',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Организации'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrganizationsPage(client: _client),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Пользователи'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => UsersPage(client: _client)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Номера'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhonesPage(client: _client),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_email_unread_outlined),
              title: const Text('Непрочитанные'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UnreadPage(client: _client),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('WA сессия'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WaPage(client: _client)),
                );
              },
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Произошла ошибка',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
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
                  'Нет чатов',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Чаты появятся здесь автоматически',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        if (!isWide) {
          return _buildChatList(isWide: false);
        }

        return Row(
          children: [
            Container(
              width: 360,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Column(
                children: [Expanded(child: _buildChatList(isWide: true))],
              ),
            ),
            Expanded(
              child: _selectedChat == null
                  ? Center(
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
                            'Выберите чат',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Нажмите на чат слева, чтобы начать общение',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ChatDetailPane(client: _client, chat: _selectedChat!),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatList({required bool isWide}) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final c = _items[i];
        final title = c.name?.isNotEmpty == true
            ? c.name!
            : (c.remoteJid ?? 'Чат #${c.id}');
        final lastTs = c.lastMessage?.timestamp ?? c.lastMessageAt;
        final lastText = c.lastMessage?.content ?? '';
        final selected = _selectedChat?.id == c.id;

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (i * 50).clamp(0, 500)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _selectedChat = c);
                  if (!isWide) {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            MessagesPage(
                              client: _client,
                              chatId: c.id,
                              initialReceiverJid: c.remoteJid,
                              initialOrganizationPhoneId: c.organizationPhoneId,
                            ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              const begin = Offset(1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.easeInOutCubic;
                              var tween = Tween(
                                begin: begin,
                                end: end,
                              ).chain(CurveTween(curve: curve));
                              var offsetAnimation = animation.drive(tween);
                              return SlideTransition(
                                position: offsetAnimation,
                                child: child,
                              );
                            },
                      ),
                    );
                  }
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Hero(
                        tag: 'chat_avatar_${c.id}',
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Icon(
                            c.isGroup == true ? Icons.groups : Icons.person,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      if (c.unreadCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              '${c.unreadCount > 9 ? '9+' : c.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: c.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastTs != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(lastTs),
                          style: TextStyle(
                            fontSize: 12,
                            color: c.unreadCount > 0
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade500,
                            fontWeight: c.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _statusChip(c.status),
                          const SizedBox(width: 6),
                          _priorityChip(c.priority),
                          if (c.assignedUser != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    c.assignedUser!.name?.isNotEmpty == true
                                        ? c.assignedUser!.name!
                                        : (c.assignedUser!.email ?? 'User'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (lastText.isNotEmpty)
                        Text(
                          lastText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(
                      c.assignedUserId != null
                          ? Icons.person
                          : Icons.person_off,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'assign_me':
                          _assignToMe(c);
                          break;
                        case 'unassign':
                          _unassignChat(c);
                          break;
                        case 'priority_low':
                          _setPriority(c, 'low');
                          break;
                        case 'priority_normal':
                          _setPriority(c, 'normal');
                          break;
                        case 'priority_high':
                          _setPriority(c, 'high');
                          break;
                        case 'priority_urgent':
                          _setPriority(c, 'urgent');
                          break;
                        case 'close':
                          _closeChat(c);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'assign_me',
                        child: Text('Назначить мне'),
                      ),
                      const PopupMenuItem(
                        value: 'unassign',
                        child: Text('Снять назначение'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'priority_low',
                        child: Text('Приоритет: низкий'),
                      ),
                      const PopupMenuItem(
                        value: 'priority_normal',
                        child: Text('Приоритет: обычный'),
                      ),
                      const PopupMenuItem(
                        value: 'priority_high',
                        child: Text('Приоритет: высокий'),
                      ),
                      const PopupMenuItem(
                        value: 'priority_urgent',
                        child: Text('Приоритет: срочный'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'close',
                        child: Text('Закрыть чат'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);

    if (diff.inDays == 0) {
      // Сегодня - показываем время
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      // Вчера - показываем "Вчера" и время
      return 'Вчера ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      // Последняя неделя - показываем день недели
      const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return days[local.weekday - 1];
    } else if (local.year == now.year) {
      // Этот год - показываем день и месяц
      return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
    } else {
      // Другой год - показываем полную дату
      return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    }
  }

  Widget _statusChip(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'open':
        color = Colors.green.shade100;
        icon = Icons.check_circle_outline;
        label = 'Открыт';
        break;
      case 'pending':
        color = Colors.orange.shade100;
        icon = Icons.pending_outlined;
        label = 'В ожидании';
        break;
      case 'closed':
        color = Colors.grey.shade200;
        icon = Icons.cancel_outlined;
        label = 'Закрыт';
        break;
      default:
        color = Colors.blue.shade100;
        icon = Icons.info_outline;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.black87),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _priorityChip(String priority) {
    Color color;

    switch (priority) {
      case 'urgent':
        color = Colors.red.shade100;
        break;
      case 'high':
        color = Colors.orange.shade100;
        break;
      case 'normal':
        color = Colors.blue.shade100;
        break;
      case 'low':
        color = Colors.grey.shade200;
        break;
      default:
        color = Colors.grey.shade200;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
