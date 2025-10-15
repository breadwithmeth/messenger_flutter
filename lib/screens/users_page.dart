import 'package:flutter/material.dart';
import 'package:messenger_flutter/api/users_service.dart';
import 'package:messenger_flutter/api/api_client.dart';

class UsersPage extends StatefulWidget {
  final ApiClient client;
  const UsersPage({super.key, required this.client});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final UsersService _users;
  List<dynamic> _items = [];
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _role;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _users = UsersService(widget.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _users.all();
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _users.create(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        name: _nameCtrl.text.trim(),
        role: _role,
      );
      _emailCtrl.clear();
      _passwordCtrl.clear();
      _nameCtrl.clear();
      _role = null;
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
      appBar: AppBar(title: const Text('Пользователи организации')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Имя'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                    DropdownMenuItem(value: 'user', child: Text('user')),
                  ],
                  onChanged: (v) => setState(() => _role = v),
                  decoration: const InputDecoration(labelText: 'Роль (опц.)'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _loading ? null : _create,
                  child: const Text('Создать пользователя'),
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
                      final u = _items[i] as Map<String, dynamic>? ?? {};
                      return ListTile(
                        title: Text(u['email']?.toString() ?? 'user'),
                        subtitle: Text(
                          'id: ${u['id'] ?? '—'} • role: ${u['role'] ?? '—'}',
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
