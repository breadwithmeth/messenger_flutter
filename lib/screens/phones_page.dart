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
      appBar: AppBar(title: const Text('Номера организации')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _jidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'phoneJid (e.g. 79001234567@s.whatsapp.net)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Отображаемое имя',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _create,
                  child: const Text('Добавить'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _items[i] as Map<String, dynamic>? ?? {};
                      final id = p['id'] as int?;
                      return ListTile(
                        title: Text(p['displayName']?.toString() ?? 'phone'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'id: ${p['id'] ?? '—'} • jid: ${p['phoneJid'] ?? '—'}',
                            ),
                            const SizedBox(height: 4),
                            _statusChip(p['status']?.toString()),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((p['qrCode'] as String?)?.isNotEmpty == true)
                              IconButton(
                                tooltip: 'Показать QR',
                                icon: const Icon(Icons.qr_code),
                                onPressed: () => _showQr(p['qrCode'] as String),
                              ),
                            IconButton(
                              tooltip: 'Connect',
                              icon: const Icon(Icons.link),
                              onPressed: id == null ? null : () => _connect(id),
                            ),
                            IconButton(
                              tooltip: 'Disconnect',
                              icon: const Icon(Icons.link_off),
                              onPressed: id == null
                                  ? null
                                  : () => _disconnect(id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

extension on _PhonesPageState {
  Widget _statusChip(String? status) {
    final s = (status ?? 'unknown').toLowerCase();
    Color bg;
    switch (s) {
      case 'connected':
        bg = Colors.green.shade100;
        break;
      case 'pending':
      case 'qr':
      case 'connecting':
        bg = Colors.orange.shade100;
        break;
      case 'disconnected':
      case 'error':
        bg = Colors.red.shade100;
        break;
      default:
        bg = Colors.grey.shade200;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('status: $s'),
    );
  }

  void _showQr(String qr) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Сканируйте QR в WhatsApp'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: Center(
              child: QrImageView(data: qr, version: QrVersions.auto, size: 260),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }
}
