import 'package:flutter/material.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:messenger_flutter/api/accounts_service.dart';
import 'package:messenger_flutter/api/api_client.dart';

class PhonesPage extends StatefulWidget {
  final ApiClient client;
  const PhonesPage({super.key, required this.client});

  @override
  State<PhonesPage> createState() => _PhonesPageState();
}

class _PhonesPageState extends State<PhonesPage> {
  late final OrganizationPhonesService _phones;
  List<dynamic> _items = [];
  final _jidCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _phones = OrganizationPhonesService(widget.client);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _jidCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _phones.all();
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_jidCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await _phones.create(
        phoneJid: _jidCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
      );
      _jidCtrl.clear();
      _nameCtrl.clear();
      await _load();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _connect(int id) async {
    setState(() => _loading = true);
    try {
      await _phones.connect(id);
      await _load();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _disconnect(int id) async {
    setState(() => _loading = true);
    try {
      await _phones.disconnect(id);
      await _load();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _loading) return;
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Номера организации'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          // Форма добавления номера
          Container(
            margin: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.phone_android,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Добавить номер WhatsApp',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _jidCtrl,
                      decoration: const InputDecoration(
                        labelText: 'JID номера',
                        hintText: '79001234567@s.whatsapp.net',
                        prefixIcon: Icon(Icons.tag),
                        helperText: 'Формат: номер@s.whatsapp.net',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Отображаемое имя',
                        hintText: 'Поддержка клиентов',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading || _jidCtrl.text.trim().isEmpty
                            ? null
                            : _create,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: Text(
                          _loading ? 'Добавление...' : 'Добавить номер',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _error = null),
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.phone_in_talk,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Подключенные номера',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_items.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phonelink_off,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет номеров',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Добавьте первый номер выше',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final p = _items[i] as Map<String, dynamic>? ?? {};
                      final id = p['id'] as int?;
                      final name = p['displayName']?.toString() ?? 'Без имени';
                      final jid = p['phoneJid']?.toString() ?? '—';
                      final status = p['status']?.toString() ?? 'unknown';
                      final hasQr =
                          (p['qrCode'] as String?)?.isNotEmpty == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        status,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getStatusIcon(status),
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          jid,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _statusChip(status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.tag,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ID: ${p['id'] ?? '—'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (hasQr) ...[
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showQr(p['qrCode'] as String),
                                      icon: const Icon(
                                        Icons.qr_code_2,
                                        size: 18,
                                      ),
                                      label: const Text('QR код'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  FilledButton.icon(
                                    onPressed: id == null
                                        ? null
                                        : (status.toLowerCase() == 'connected'
                                              ? () => _disconnect(id)
                                              : () => _connect(id)),
                                    icon: Icon(
                                      status.toLowerCase() == 'connected'
                                          ? Icons.link_off
                                          : Icons.link,
                                      size: 18,
                                    ),
                                    label: Text(
                                      status.toLowerCase() == 'connected'
                                          ? 'Отключить'
                                          : 'Подключить',
                                    ),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      backgroundColor:
                                          status.toLowerCase() == 'connected'
                                          ? Colors.red.shade400
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
        return Icons.check_circle;
      case 'pending':
      case 'qr':
      case 'connecting':
        return Icons.sync;
      case 'disconnected':
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
        return Colors.green;
      case 'pending':
      case 'qr':
      case 'connecting':
        return Colors.orange;
      case 'disconnected':
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

extension on _PhonesPageState {
  Widget _statusChip(String? status) {
    final s = (status ?? 'unknown').toLowerCase();
    Color bg;
    IconData icon;
    String label;

    switch (s) {
      case 'connected':
        bg = Colors.green.shade100;
        icon = Icons.check_circle;
        label = 'Подключен';
        break;
      case 'pending':
      case 'qr':
      case 'connecting':
        bg = Colors.orange.shade100;
        icon = Icons.pending;
        label = 'Ожидание';
        break;
      case 'disconnected':
        bg = Colors.grey.shade200;
        icon = Icons.power_off;
        label = 'Отключен';
        break;
      case 'error':
        bg = Colors.red.shade100;
        icon = Icons.error;
        label = 'Ошибка';
        break;
      default:
        bg = Colors.grey.shade200;
        icon = Icons.help_outline;
        label = s;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showQr(String qr) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.qr_code_2,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Сканируйте в WhatsApp',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qr,
                    version: QrVersions.auto,
                    size: 280,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Откройте WhatsApp → Настройки → Связанные устройства',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
