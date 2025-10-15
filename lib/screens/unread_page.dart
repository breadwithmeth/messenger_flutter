import 'package:flutter/material.dart';
import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/api/unread_service.dart';

class UnreadPage extends StatefulWidget {
  final ApiClient client;
  const UnreadPage({super.key, required this.client});

  @override
  State<UnreadPage> createState() => _UnreadPageState();
}

class _UnreadPageState extends State<UnreadPage> {
  late final UnreadService _unread;
  Map<String, dynamic>? _counts;
  List<dynamic> _chats = [];
  bool _assignedOnly = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unread = UnreadService(widget.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final counts = await _unread.counts();
      final chats = await _unread.chats(assignedOnly: _assignedOnly);
      setState(() {
        _counts = counts;
        _chats = chats;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Непрочитанные')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Только назначенные'),
            value: _assignedOnly,
            onChanged: (v) => setState(() => _assignedOnly = v),
            secondary: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_counts != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Всего: ${_counts!['total']}\nНазначенные: ${_counts!['assigned']}',
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _chats.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = _chats[i] as Map<String, dynamic>? ?? {};
                      return ListTile(
                        title: Text('Чат #${c['id'] ?? '—'}'),
                        subtitle: Text('unread: ${c['unreadCount'] ?? '—'}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
