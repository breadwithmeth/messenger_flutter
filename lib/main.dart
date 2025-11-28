import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'api/api_client.dart';
import 'api/auth_service.dart';
import 'api/chats_service.dart';
import 'api/unread_service.dart';
import 'api/accounts_service.dart';
import 'models/chat_models.dart';
import 'config.dart';
import 'screens/login_page.dart';
import 'screens/organizations_page.dart';
import 'screens/users_page.dart';
import 'screens/phones_page.dart';
import 'screens/unread_page.dart';
import 'screens/messages_page.dart';
import 'screens/wa_page.dart';
import 'screens/telegram_bots_page.dart';
import 'screens/settings_page.dart';
import 'models/auth_models.dart';
import 'theme_provider.dart';
import 'theme_colors.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Messenger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.neutral,
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
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.neutral,
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
      themeMode: _themeProvider.themeMode,
      home: MyHomePage(title: 'Чаты', themeProvider: _themeProvider),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.themeProvider,
  });

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final ThemeProvider themeProvider;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final ApiClient _client;
  late final AuthService _auth;
  late final ChatsService _chats;
  late final UnreadService _unread;
  List<ChatDto> _items = [];
  bool _loading = false;
  String? _error;
  UserDto? _me;
  ChatDto? _selectedChat;
  bool _loadingSelectedChat = false;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(baseUrl: AppConfig.baseUrl);
    _auth = AuthService(_client);
    _chats = ChatsService(_client);
    _unread = UnreadService(_client);
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

  Future<void> _loadChats() async {
    final resp = await _chats.listChats(
      sortBy: 'lastMessageAt',
      sortOrder: 'desc',
    );
    setState(() {
      // Сервер уже вернул отсортированные чаты
      _items = resp.chats;

      if (_selectedChat != null) {
        final selId = _selectedChat!.id;
        final idx = _items.indexWhere((e) => e.id == selId);
        _selectedChat = idx >= 0 ? _items[idx] : null;
      }
    });
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
      // Показываем диалог подтверждения
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

      // Помечаем все непрочитанные чаты
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

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 10), (_) async {
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
      appBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
        leading: Builder(
          builder: (context) => CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Scaffold.of(context).openDrawer(),
            child: const Icon(CupertinoIcons.line_horizontal_3, size: 28),
          ),
        ),
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2_fill,
              color: CupertinoColors.activeBlue.resolveFrom(context),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showNewChatDialog,
              child: const Icon(
                CupertinoIcons.plus_circle_fill,
                color: CupertinoColors.activeBlue,
                size: 28,
              ),
            ),
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
      drawer: Drawer(
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator.resolveFrom(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CupertinoColors.systemGrey5.resolveFrom(context),
                      ),
                      child: Icon(
                        CupertinoIcons.person_fill,
                        size: 32,
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _me?.email ?? 'Мессенджер',
                      style: TextStyle(
                        color: CupertinoColors.label.resolveFrom(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Организации
              CupertinoListTile(
                leading: Icon(
                  CupertinoIcons.building_2_fill,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
                title: Text(
                  'Организации',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 20,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => OrganizationsPage(client: _client),
                    ),
                  );
                },
              ),
              // Пользователи
              CupertinoListTile(
                leading: Icon(
                  CupertinoIcons.person_2_fill,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
                title: Text(
                  'Пользователи',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 20,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => UsersPage(client: _client),
                    ),
                  );
                },
              ),
              // Номера
              CupertinoListTile(
                leading: Icon(
                  CupertinoIcons.device_phone_portrait,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
                title: Text(
                  'Номера',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 20,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => PhonesPage(client: _client),
                    ),
                  );
                },
              ),
              // Непрочитанные
              CupertinoListTile(
                leading: Icon(
                  CupertinoIcons.envelope_badge_fill,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
                title: Text(
                  'Непрочитанные',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 20,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => UnreadPage(client: _client),
                    ),
                  );
                },
              ),
              // WA сессия
              CupertinoListTile(
                leading: Icon(
                  CupertinoIcons.chat_bubble_2_fill,
                  color: CupertinoColors.systemGreen.resolveFrom(context),
                ),
                title: Text(
                  'WA сессия',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 20,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => WaPage(client: _client)),
                  );
                },
              ),
              // Telegram боты
              CupertinoListTile(
                leading: Icon(
                  CupertinoIcons.chat_bubble_text_fill,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
                title: Text(
                  'Telegram боты',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 20,
                ),
                onTap: () {
                  Navigator.pop(context);
                  final orgId = _me?.organizationId ?? 1;
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => TelegramBotsPage(
                        client: _client,
                        organizationId: orgId,
                      ),
                    ),
                  );
                },
              ),
              // Разделитель
              Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: CupertinoColors.separator.resolveFrom(context),
              ),
              // Настройки
              CupertinoListTile(
                leading: Icon(
                  CupertinoIcons.settings,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                ),
                title: Text(
                  'Настройки',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 20,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
              // Разделитель
              Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: CupertinoColors.separator.resolveFrom(context),
              ),
              // Заголовок секции
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'ОФОРМЛЕНИЕ',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.08,
                  ),
                ),
              ),
              // Тема
              CupertinoListTile(
                leading: Icon(
                  widget.themeProvider.isLight
                      ? CupertinoIcons.sun_max_fill
                      : widget.themeProvider.isDark
                      ? CupertinoIcons.moon_fill
                      : CupertinoIcons.brightness,
                  color: CupertinoColors.systemOrange.resolveFrom(context),
                ),
                title: Text(
                  'Тема',
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                subtitle: Text(
                  widget.themeProvider.isLight
                      ? 'Светлая'
                      : widget.themeProvider.isDark
                      ? 'Темная'
                      : 'Системная',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 14,
                  ),
                ),
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 20,
                ),
                onTap: () {
                  _showThemeDialog();
                },
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Future<void> _showNewChatDialog() async {
    final phoneController = TextEditingController();
    final jidController = TextEditingController();
    int? selectedOrgPhoneId;
    List<dynamic> orgPhones = [];

    // Загружаем доступные номера организации
    try {
      final phonesService = OrganizationPhonesService(_client);
      orgPhones = await phonesService.all();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки номеров: $e'),
            backgroundColor: CupertinoColors.systemRed,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Новый чат'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Номер клиента',
                    hintText: '79991234567 плюс не писать',
                    prefixIcon: Icon(CupertinoIcons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: jidController,
                  decoration: const InputDecoration(
                    labelText: 'JID (опционально)',
                    hintText: '79991234567@s.whatsapp.net',
                    prefixIcon: Icon(CupertinoIcons.at),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedOrgPhoneId,
                  decoration: const InputDecoration(
                    labelText: 'Номер организации',
                    prefixIcon: Icon(CupertinoIcons.building_2_fill),
                  ),
                  items: orgPhones
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
                  onChanged: (value) {
                    setState(() {
                      selectedOrgPhoneId = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (phoneController.text.isEmpty ||
                    selectedOrgPhoneId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Заполните номер клиента и выберите номер организации',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'phone': phoneController.text,
                  'jid': jidController.text.isEmpty ? null : jidController.text,
                  'orgPhoneId': selectedOrgPhoneId,
                });
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await _createNewChat(
        result['phone'] as String,
        result['jid'] as String?,
        result['orgPhoneId'] as int,
      );
    }
  }

  Future<void> _createNewChat(String phone, String? jid, int orgPhoneId) async {
    // Просто открываем страницу сообщений с новым клиентом
    // Чат создастся автоматически при отправке первого сообщения
    if (!mounted) return;

    final receiverJid = jid ?? '$phone@s.whatsapp.net';

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => MessagesPage(
              client: _client,
              chatId: 0, // Новый чат, ID будет создан после первого сообщения
              initialReceiverJid: receiverJid,
              initialOrganizationPhoneId: orgPhoneId,
            ),
          ),
        )
        .then((_) {
          // После возврата обновляем список чатов
          _loadChats();
        });
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выбор темы'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('Светлая'),
                subtitle: const Text('Всегда использовать светлую тему'),
                secondary: const Icon(CupertinoIcons.sun_max_fill),
                value: ThemeMode.light,
                groupValue: widget.themeProvider.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    widget.themeProvider.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Темная'),
                subtitle: const Text('Всегда использовать темную тему'),
                secondary: const Icon(CupertinoIcons.moon_fill),
                value: ThemeMode.dark,
                groupValue: widget.themeProvider.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    widget.themeProvider.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Системная'),
                subtitle: const Text('Следовать настройкам системы'),
                secondary: const Icon(CupertinoIcons.brightness),
                value: ThemeMode.system,
                groupValue: widget.themeProvider.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    widget.themeProvider.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
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
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 64,
                color: CupertinoColors.systemRed.resolveFrom(context),
              ),
              const SizedBox(height: 16),
              Text(
                'Произошла ошибка',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(context),
                ),
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
                  CupertinoIcons.chat_bubble_2,
                  size: 80,
                  color: CupertinoColors.systemGrey
                      .resolveFrom(context)
                      .withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Нет чатов',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Чаты появятся здесь автоматически',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary(context),
                  ),
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
                            CupertinoIcons.chat_bubble_2,
                            size: 80,
                            color: CupertinoColors.systemGrey
                                .resolveFrom(context)
                                .withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Выберите чат',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary(context),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Нажмите на чат слева, чтобы посмотреть сообщения',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textTertiary(context),
                                ),
                          ),
                        ],
                      ),
                    )
                  : _loadingSelectedChat
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Загрузка чата...',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary(context),
                                ),
                          ),
                        ],
                      ),
                    )
                  : MessagesPage(
                      client: _client,
                      chatId: _selectedChat!.id,
                      initialReceiverJid: _selectedChat!.remoteJid,
                      initialOrganizationPhoneId:
                          _selectedChat!.organizationPhoneId,
                      chat: _selectedChat, // Передаем объект чата
                    ),
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
        final t = _items[i];
        final title = t.displayName; // Используем новый геттер
        final lastTs = t.lastMessage?.timestamp;
        final lastText = t.lastMessage?.content ?? '';
        final selected = _selectedChat?.id == t.id;

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
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            decoration: BoxDecoration(
              color: selected
                  ? CupertinoColors.systemGrey6.resolveFrom(context)
                  : CupertinoColors.systemBackground.resolveFrom(context),
              border: Border(
                bottom: BorderSide(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.5,
                ),
              ),
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                setState(() {
                  _selectedChat = t;
                  _loadingSelectedChat = true;
                });

                // Небольшая задержка для показа индикатора загрузки
                await Future.delayed(const Duration(milliseconds: 100));

                setState(() {
                  _loadingSelectedChat = false;
                });

                if (!isWide) {
                  await Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          MessagesPage(
                            client: _client,
                            chatId: t.id,
                            initialReceiverJid: t.remoteJid,
                            initialOrganizationPhoneId: t.organizationPhoneId,
                            chat: t, // Передаем объект чата
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

                  // После возврата со страницы сообщений — обновим список
                  try {
                    await _loadChats();
                  } catch (_) {
                    // Игнорируем ошибки при немедленном обновлении
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Hero(
                          tag: 'chat_avatar_${t.id}',
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.isTelegram
                                  ? CupertinoColors.activeBlue
                                        .resolveFrom(context)
                                        .withOpacity(0.1)
                                  : CupertinoColors.systemGrey5.resolveFrom(
                                      context,
                                    ),
                            ),
                            child: Icon(
                              t.isTelegram
                                  ? CupertinoIcons.chat_bubble_text_fill
                                  : CupertinoIcons.person_fill,
                              color: t.isTelegram
                                  ? CupertinoColors.activeBlue.resolveFrom(
                                      context,
                                    )
                                  : CupertinoColors.systemGrey.resolveFrom(
                                      context,
                                    ),
                              size: 24,
                            ),
                          ),
                        ),
                        if (t.unreadCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemRed,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                '${t.unreadCount > 99 ? '99+' : t.unreadCount}',
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (t.isTelegram) ...[
                                Icon(
                                  CupertinoIcons.chat_bubble_text_fill,
                                  size: 14,
                                  color: CupertinoColors.activeBlue.resolveFrom(
                                    context,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: t.unreadCount > 0
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: CupertinoColors.label.resolveFrom(
                                      context,
                                    ),
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
                                    fontSize: 15,
                                    color: t.unreadCount > 0
                                        ? CupertinoColors.activeBlue
                                        : CupertinoColors.secondaryLabel
                                              .resolveFrom(context),
                                    fontWeight: t.unreadCount > 0
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (lastText.isNotEmpty)
                            Text(
                              lastText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          // Отображение назначенного оператора
                          if (t.assignedUser != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.person_circle_fill,
                                  size: 14,
                                  color: CupertinoColors.systemGreen
                                      .resolveFrom(context),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    t.assignedUser!.name ??
                                        t.assignedUser!.email ??
                                        'Оператор #${t.assignedUser!.id}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.systemGreen
                                          .resolveFrom(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
}
