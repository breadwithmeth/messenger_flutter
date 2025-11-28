import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/api/telegram_bots_service.dart';
import 'package:messenger_flutter/models/telegram_bot_models.dart';
import 'dart:async';

class TelegramBotsPage extends StatefulWidget {
  final ApiClient client;
  final int organizationId;

  const TelegramBotsPage({
    super.key,
    required this.client,
    required this.organizationId,
  });

  @override
  State<TelegramBotsPage> createState() => _TelegramBotsPageState();
}

class _TelegramBotsPageState extends State<TelegramBotsPage> {
  late final TelegramBotsService _botsService;
  List<TelegramBotDto> _bots = [];
  bool _loading = false;
  String? _error;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _botsService = TelegramBotsService(widget.client);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poller = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _load(showLoading: false),
    );
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    try {
      final response = await _botsService.listBots(widget.organizationId);
      if (mounted) {
        setState(() {
          _bots = response.bots;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _showCreateBotDialog() async {
    final tokenCtrl = TextEditingController();
    final welcomeCtrl = TextEditingController();
    bool autoStart = true;

    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Создать Telegram бота'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Получите токен у @BotFather в Telegram:\n1. /newbot\n2. Укажите имя и username\n3. Скопируйте токен',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: tokenCtrl,
              placeholder: 'Токен бота (1234567890:ABC...)',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: welcomeCtrl,
              placeholder: 'Приветственное сообщение',
              padding: const EdgeInsets.all(12),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final token = tokenCtrl.text.trim();
              if (token.isEmpty) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(context);
              await _createBot(
                token,
                welcomeCtrl.text.trim().isNotEmpty
                    ? welcomeCtrl.text.trim()
                    : null,
                autoStart,
              );
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBot(
    String token,
    String? welcomeMessage,
    bool autoStart,
  ) async {
    setState(() => _loading = true);
    try {
      await _botsService.createBot(
        organizationId: widget.organizationId,
        botToken: token,
        welcomeMessage: welcomeMessage,
        autoStart: autoStart,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Бот успешно создан')));
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleBot(TelegramBotDto bot) async {
    try {
      if (bot.isRunning) {
        await _botsService.stopBot(bot.id);
      } else {
        await _botsService.startBot(bot.id);
      }
      await _load(showLoading: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _deleteBot(TelegramBotDto bot) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Удалить бота?'),
        content: Text('Бот @${bot.botUsername ?? "неизвестен"} будет удален'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _botsService.deleteBot(bot.id);
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Бот удален')));
        }
      } catch (e) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return CupertinoColors.systemGreen;
      case 'inactive':
        return CupertinoColors.systemGrey;
      case 'error':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
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
        middle: const Text(
          'Telegram боты',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showCreateBotDialog,
              child: Icon(
                CupertinoIcons.add_circled_solid,
                color: CupertinoColors.activeBlue.resolveFrom(context),
                size: 28,
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _load(),
              child: Icon(
                CupertinoIcons.refresh_circled_solid,
                color: CupertinoColors.activeBlue.resolveFrom(context),
                size: 28,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _loading && _bots.isEmpty
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null && _bots.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_triangle,
                        size: 48,
                        color: CupertinoColors.systemRed.resolveFrom(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton.filled(
                        onPressed: () => _load(),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              )
            : _bots.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.chat_bubble_2,
                      size: 64,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Нет ботов',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Создайте бота для начала работы',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CupertinoButton.filled(
                      onPressed: _showCreateBotDialog,
                      child: const Text('Создать бота'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _bots.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                itemBuilder: (context, index) {
                  final bot = _bots[index];
                  return CupertinoListTile(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor(bot.status).withOpacity(0.1),
                      ),
                      child: Icon(
                        CupertinoIcons.chat_bubble_text_fill,
                        color: _getStatusColor(bot.status),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      bot.botName ?? bot.botUsername ?? 'Бот #${bot.id}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bot.botUsername != null)
                          Text(
                            '@${bot.botUsername}',
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              bot.isRunning
                                  ? CupertinoIcons.play_circle_fill
                                  : CupertinoIcons.pause_circle_fill,
                              size: 14,
                              color: bot.isRunning
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              bot.isRunning ? 'Запущен' : 'Остановлен',
                              style: TextStyle(
                                fontSize: 12,
                                color: bot.isRunning
                                    ? CupertinoColors.systemGreen
                                    : CupertinoColors.systemGrey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              bot.status,
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(bot.status),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _toggleBot(bot),
                          child: Icon(
                            bot.isRunning
                                ? CupertinoIcons.stop_circle
                                : CupertinoIcons.play_circle,
                            color: CupertinoColors.activeBlue.resolveFrom(
                              context,
                            ),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _deleteBot(bot),
                          child: Icon(
                            CupertinoIcons.delete,
                            color: CupertinoColors.systemRed.resolveFrom(
                              context,
                            ),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
