import 'package:messenger_flutter/api/api_client.dart';

class WaService {
  final ApiClient _client;
  WaService(this._client);

  Future<Map<String, dynamic>> start() async {
    final res = await _client.postJson('/api/wa/start');
    return res.data as Map<String, dynamic>;
  }
}
