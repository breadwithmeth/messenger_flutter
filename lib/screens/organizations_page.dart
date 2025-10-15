import 'package:flutter/material.dart';
import 'package:messenger_flutter/api/organizations_service.dart';
import 'package:messenger_flutter/api/api_client.dart';

class OrganizationsPage extends StatefulWidget {
  final ApiClient client;
  const OrganizationsPage({super.key, required this.client});

  @override
  State<OrganizationsPage> createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends State<OrganizationsPage> {
  late final OrganizationsService _orgs;
  List<dynamic> _items = [];
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _orgs = OrganizationsService(widget.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _orgs.list();
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _orgs.create(name);
      _nameCtrl.clear();
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
      appBar: AppBar(title: const Text('Организации')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Название организации',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _create,
                  child: const Text('Создать'),
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
                      final o = _items[i] as Map<String, dynamic>? ?? {};
                      return ListTile(
                        title: Text(o['name']?.toString() ?? 'org'),
                        subtitle: Text('id: ${o['id'] ?? '—'}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
