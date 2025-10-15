import 'package:flutter/material.dart';
import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/api/wa_service.dart';

class WaPage extends StatefulWidget {
  final ApiClient client;
  const WaPage({super.key, required this.client});

  @override
  State<WaPage> createState() => _WaPageState();
}

class _WaPageState extends State<WaPage> {
  late final WaService _wa;
  String? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _wa = WaService(widget.client);
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await _wa.start();
      setState(() => _result = res.toString());
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp сессия')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _loading ? null : _start,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Запустить сессию'),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_result != null)
              Expanded(child: SingleChildScrollView(child: Text(_result!))),
          ],
        ),
      ),
    );
  }
}
