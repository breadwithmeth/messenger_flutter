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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Messenger Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Чаты организации'),
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

  @override
  void initState() {
    super.initState();
    _client = ApiClient(baseUrl: AppConfig.baseUrl);
    _auth = AuthService(_client);
    _chats = ChatsService(_client);
    _assign = ChatAssignmentService(_client);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Если токена нет — покажем кнопку логина ниже; просто проверим присутствие
      final token = await _client.getToken();
      if (token != null && token.isNotEmpty) {
        // Получим текущего пользователя для operatorId при назначении
        _me = await _auth.me();
        await _loadChats();
      }
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

  Future<void> _openLogin() async {
    final success = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => LoginPage(auth: _auth)));
    if (success == true) {
      await _loadChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
            const DrawerHeader(child: Text('Меню')),
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
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
                const Text('Не авторизованы или нет чатов'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _openLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Войти'),
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
            SizedBox(
              width: 360,
              child: Column(
                children: [Expanded(child: _buildChatList(isWide: true))],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selectedChat == null
                  ? const Center(child: Text('Выберите чат слева'))
                  : ChatDetailPane(client: _client, chat: _selectedChat!),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatList({required bool isWide}) {
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = _items[i];
        final title = c.name?.isNotEmpty == true
            ? c.name!
            : (c.remoteJid ?? 'Чат #${c.id}');
        final lastTs = c.lastMessage?.timestamp ?? c.lastMessageAt;
        final lastText = c.lastMessage?.content ?? '';
        final selected = _selectedChat?.id == c.id;
        return ListTile(
          selected: selected,
          leading: Stack(
            alignment: Alignment.topRight,
            children: [
              Icon(
                c.isGroup == true ? Icons.groups : Icons.chat_bubble_outline,
              ),
              if (c.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${c.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
            ],
          ),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _chip(c.status, Colors.blueGrey.shade100),
                  const SizedBox(width: 6),
                  _chip('prio: ${c.priority}', Colors.deepOrange.shade100),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${c.organizationPhone?.displayName ?? c.organizationPhone?.phoneJid ?? ''}'
                '${(c.organizationPhone?.displayName != null || c.organizationPhone?.phoneJid != null) ? ' • ' : ''}'
                '${lastText.isNotEmpty ? lastText : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                lastTs != null
                    ? lastTs.toLocal().toString().substring(0, 19)
                    : '—',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(
              c.assignedUserId != null ? Icons.person : Icons.person_off,
              size: 20,
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
                child: Text('Приоритет: low'),
              ),
              const PopupMenuItem(
                value: 'priority_normal',
                child: Text('Приоритет: normal'),
              ),
              const PopupMenuItem(
                value: 'priority_high',
                child: Text('Приоритет: high'),
              ),
              const PopupMenuItem(
                value: 'priority_urgent',
                child: Text('Приоритет: urgent'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'close', child: Text('Закрыть чат')),
            ],
          ),
          onTap: () {
            if (isWide) {
              setState(() => _selectedChat = c);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MessagesPage(
                    client: _client,
                    chatId: c.id,
                    initialReceiverJid: c.remoteJid,
                    initialOrganizationPhoneId: c.organizationPhoneId,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _chip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
