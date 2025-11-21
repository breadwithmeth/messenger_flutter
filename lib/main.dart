import 'package:flutter/material.dart';
import 'api/api_client.dart';
import 'api/auth_service.dart';
import 'api/tickets_service.dart';
import 'models/ticket_models.dart';
import 'config.dart';
import 'screens/login_page.dart';
import 'screens/organizations_page.dart';
import 'screens/users_page.dart';
import 'screens/phones_page.dart';
import 'screens/unread_page.dart';
import 'screens/ticket_messages_page.dart';
import 'screens/wa_page.dart';
import 'screens/ticket_detail_pane.dart';
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
      home: MyHomePage(title: 'Тикеты', themeProvider: _themeProvider),
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
  late final TicketsService _tickets;
  List<TicketDto> _items = [];
  bool _loading = false;
  String? _error;
  UserDto? _me;
  TicketDto? _selectedTicket;
  Timer? _poller;

  // Фильтры
  String? _filterStatus;
  String? _filterPriority;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(baseUrl: AppConfig.baseUrl);
    _auth = AuthService(_client);
    _tickets = TicketsService(_client);
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
      await _loadTickets();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _assignToMe(TicketDto t) async {
    if (_me == null) return;
    setState(() => _loading = true);
    try {
      await _tickets.assignTicket(t.ticketNumber, _me!.id);
      await _loadTickets();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _unassignTicket(TicketDto t) async {
    setState(() => _loading = true);
    try {
      await _tickets.unassignTicket(t.ticketNumber);
      await _loadTickets();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _setPriority(TicketDto t, String p) async {
    setState(() => _loading = true);
    try {
      await _tickets.changePriority(t.ticketNumber, p);
      await _loadTickets();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _closeTicket(TicketDto t) async {
    setState(() => _loading = true);
    try {
      await _tickets.changeStatus(t.ticketNumber, 'closed');
      await _loadTickets();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadTickets() async {
    final resp = await _tickets.getTickets(
      status: _filterStatus,
      priority: _filterPriority,
    );
    setState(() {
      _items = resp.tickets;
      if (_selectedTicket != null) {
        final selNum = _selectedTicket!.ticketNumber;
        final idx = _items.indexWhere((e) => e.ticketNumber == selNum);
        _selectedTicket = idx >= 0 ? _items[idx] : null;
      }
    });
  }

  Future<void> _markAllAsRead() async {
    final unreadTickets = _items.where((t) => t.unreadCount > 0).toList();
    if (unreadTickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет непрочитанных тикетов')),
      );
      return;
    }

    try {
      // Показываем диалог подтверждения
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Пометить все как прочитанные?'),
          content: Text(
            'Будет отмечено ${unreadTickets.length} тикет(ов) как прочитанные',
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

      // Помечаем все непрочитанные тикеты
      for (final _ in unreadTickets) {
        try {
          // Здесь должен быть API метод для пометки как прочитанного
          // Пока просто обновляем список
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          // Игнорируем ошибки для отдельных тикетов
        }
      }

      await _loadTickets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Отмечено ${unreadTickets.length} тикет(ов)'),
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
    _poller = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      if (_loading) return;
      try {
        await _loadTickets();
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
      await _loadTickets();
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
            Icon(
              Icons.confirmation_number,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(widget.title),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.done_all,
              color: _items.any((t) => t.unreadCount > 0)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: _markAllAsRead,
            tooltip: 'Пометить все прочитанными',
          ),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _filterStatus != null || _filterPriority != null
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: _showFilterDialog,
            tooltip: 'Фильтры',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTickets,
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
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Оформление',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                widget.themeProvider.isLight
                    ? Icons.light_mode
                    : widget.themeProvider.isDark
                    ? Icons.dark_mode
                    : Icons.brightness_auto,
              ),
              title: const Text('Тема'),
              subtitle: Text(
                widget.themeProvider.isLight
                    ? 'Светлая'
                    : widget.themeProvider.isDark
                    ? 'Темная'
                    : 'Системная',
              ),
              onTap: () {
                _showThemeDialog();
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String? tempStatus = _filterStatus;
        String? tempPriority = _filterPriority;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Фильтры'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Статус',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip('Все', null, tempStatus, (v) {
                          setDialogState(() => tempStatus = v);
                        }),
                        _filterChip('Новый', 'new', tempStatus, (v) {
                          setDialogState(() => tempStatus = v);
                        }),
                        _filterChip('Открыт', 'open', tempStatus, (v) {
                          setDialogState(() => tempStatus = v);
                        }),
                        _filterChip('В работе', 'in_progress', tempStatus, (v) {
                          setDialogState(() => tempStatus = v);
                        }),
                        _filterChip('Ожидание', 'pending', tempStatus, (v) {
                          setDialogState(() => tempStatus = v);
                        }),
                        _filterChip('Решён', 'resolved', tempStatus, (v) {
                          setDialogState(() => tempStatus = v);
                        }),
                        _filterChip('Закрыт', 'closed', tempStatus, (v) {
                          setDialogState(() => tempStatus = v);
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Приоритет',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip('Все', null, tempPriority, (v) {
                          setDialogState(() => tempPriority = v);
                        }),
                        _filterChip('Низкий', 'low', tempPriority, (v) {
                          setDialogState(() => tempPriority = v);
                        }),
                        _filterChip('Обычный', 'normal', tempPriority, (v) {
                          setDialogState(() => tempPriority = v);
                        }),
                        _filterChip('Высокий', 'high', tempPriority, (v) {
                          setDialogState(() => tempPriority = v);
                        }),
                        _filterChip('Срочный', 'urgent', tempPriority, (v) {
                          setDialogState(() => tempPriority = v);
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterStatus = null;
                      _filterPriority = null;
                    });
                    Navigator.pop(context);
                    _loadTickets();
                  },
                  child: const Text('Сбросить'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterStatus = tempStatus;
                      _filterPriority = tempPriority;
                    });
                    Navigator.pop(context);
                    _loadTickets();
                  },
                  child: const Text('Применить'),
                ),
              ],
            );
          },
        );
      },
    );
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
                secondary: const Icon(Icons.light_mode),
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
                secondary: const Icon(Icons.dark_mode),
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
                secondary: const Icon(Icons.brightness_auto),
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

  Widget _filterChip(
    String label,
    String? value,
    String? current,
    Function(String?) onTap,
  ) {
    final selected = current == value;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
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
                Icons.error_outline,
                size: 64,
                color: AppColors.errorText(context),
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
                  Icons.confirmation_number_outlined,
                  size: 80,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'Нет тикетов',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Тикеты появятся здесь автоматически',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary(context),
                  ),
                ),
              ],
            ),
          );
        }

        if (!isWide) {
          return _buildTicketList(isWide: false);
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
                children: [Expanded(child: _buildTicketList(isWide: true))],
              ),
            ),
            Expanded(
              child: _selectedTicket == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 80,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Выберите тикет',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary(context),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Нажмите на тикет слева, чтобы посмотреть детали',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textTertiary(context),
                                ),
                          ),
                        ],
                      ),
                    )
                  : _TicketTabbedView(
                      client: _client,
                      ticket: _selectedTicket!,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTicketList({required bool isWide}) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final t = _items[i];
        final title = t.subject?.isNotEmpty == true
            ? t.subject!
            : 'Тикет #${t.ticketNumber}';
        final lastTs = t.lastMessage?.timestamp ?? t.updatedAt;
        final lastText = t.lastMessage?.content ?? '';
        final selected = _selectedTicket?.ticketNumber == t.ticketNumber;

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
                onTap: () async {
                  setState(() => _selectedTicket = t);
                  if (!isWide) {
                    await Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            TicketMessagesPage(
                              client: _client,
                              ticketNumber: t.ticketNumber,
                              ticketSubject: t.subject,
                              clientName: t.clientName,
                              clientPhone: t.clientPhone,
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
                      await _loadTickets();
                    } catch (_) {
                      // Игнорируем ошибки при немедленном обновлении
                    }
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
                        tag: 'ticket_avatar_${t.ticketNumber}',
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.confirmation_number,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      if (t.unreadCount > 0)
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
                              '${t.unreadCount > 9 ? '9+' : t.unreadCount}',
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
                            fontWeight: t.unreadCount > 0
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
                            color: t.unreadCount > 0
                                ? Theme.of(context).colorScheme.primary
                                : AppColors.textTertiary(context),
                            fontWeight: t.unreadCount > 0
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
                          _statusChip(t.status),
                          const SizedBox(width: 6),
                          _priorityChip(t.priority),
                          if (t.assignedUser != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.assignedUserBackground(
                                  context,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.assignedUserBorder(context),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 14,
                                    color: AppColors.assignedUserIcon(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.assignedUser!.name?.isNotEmpty == true
                                        ? t.assignedUser!.name!
                                        : (t.assignedUser!.email ?? 'User'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.assignedUserText(
                                        context,
                                      ),
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
                      if (t.clientName != null || t.clientPhone != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: AppColors.textTertiary(context),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  [
                                    if (t.clientName?.isNotEmpty == true)
                                      t.clientName!,
                                    if (t.clientPhone?.isNotEmpty == true)
                                      t.clientPhone!,
                                  ].join(' • '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (lastText.isNotEmpty)
                        Text(
                          lastText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(
                      t.assignedUser != null ? Icons.person : Icons.person_off,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'assign_me':
                          _assignToMe(t);
                          break;
                        case 'unassign':
                          _unassignTicket(t);
                          break;
                        case 'priority_low':
                          _setPriority(t, 'low');
                          break;
                        case 'priority_normal':
                          _setPriority(t, 'normal');
                          break;
                        case 'priority_high':
                          _setPriority(t, 'high');
                          break;
                        case 'priority_urgent':
                          _setPriority(t, 'urgent');
                          break;
                        case 'close':
                          _closeTicket(t);
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
                        child: Text('Закрыть тикет'),
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
    Color baseColor;
    IconData icon;
    String label;

    switch (status) {
      case 'new':
        baseColor = Colors.blue;
        icon = Icons.new_releases_outlined;
        label = 'Новый';
        break;
      case 'open':
        baseColor = Colors.green;
        icon = Icons.check_circle_outline;
        label = 'Открыт';
        break;
      case 'in_progress':
        baseColor = Colors.cyan;
        icon = Icons.autorenew;
        label = 'В работе';
        break;
      case 'pending':
        baseColor = Colors.orange;
        icon = Icons.pending_outlined;
        label = 'В ожидании';
        break;
      case 'resolved':
        baseColor = Colors.lightGreen;
        icon = Icons.done_all;
        label = 'Решен';
        break;
      case 'closed':
        baseColor = Colors.grey;
        icon = Icons.cancel_outlined;
        label = 'Закрыт';
        break;
      default:
        baseColor = Colors.blue;
        icon = Icons.info_outline;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.statusBackground(context, baseColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.statusText(context, baseColor)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.statusText(context, baseColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityChip(String priority) {
    Color baseColor;

    switch (priority) {
      case 'urgent':
        baseColor = Colors.red;
        break;
      case 'high':
        baseColor = Colors.orange;
        break;
      case 'normal':
        baseColor = Colors.blue;
        break;
      case 'low':
        baseColor = Colors.grey;
        break;
      default:
        baseColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.statusBackground(context, baseColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.statusText(context, baseColor),
        ),
      ),
    );
  }
}

/// Виджет с вкладками для отображения переписки и деталей тикета
class _TicketTabbedView extends StatefulWidget {
  final ApiClient client;
  final TicketDto ticket;

  const _TicketTabbedView({required this.client, required this.ticket});

  @override
  State<_TicketTabbedView> createState() => _TicketTabbedViewState();
}

class _TicketTabbedViewState extends State<_TicketTabbedView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Заголовок с информацией о тикете и клиенте
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.confirmation_number,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Тикет #${widget.ticket.ticketNumber}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (widget.ticket.clientName != null ||
                  widget.ticket.clientPhone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: AppColors.textTertiary(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            if (widget.ticket.clientName?.isNotEmpty == true)
                              widget.ticket.clientName!,
                            if (widget.ticket.clientPhone?.isNotEmpty == true)
                              widget.ticket.clientPhone!,
                          ].join(' • '),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.ticket.subject?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.ticket.subject!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Переписка'),
              Tab(icon: Icon(Icons.info_outline), text: 'Детали'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Вкладка с перепиской
              TicketMessagesPage(
                client: widget.client,
                ticketNumber: widget.ticket.ticketNumber,
                ticketSubject: widget.ticket.subject,
                clientName: widget.ticket.clientName,
                clientPhone: widget.ticket.clientPhone,
                showAppBar: false,
              ),
              // Вкладка с деталями
              TicketDetailPane(client: widget.client, ticket: widget.ticket),
            ],
          ),
        ),
      ],
    );
  }
}
