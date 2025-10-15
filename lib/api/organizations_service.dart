import 'package:messenger_flutter/api/api_client.dart';

class OrganizationsService {
  final ApiClient _client;
  OrganizationsService(this._client);

  Future<Map<String, dynamic>> create(String name) async {
    final res = await _client.postJson(
      '/api/organizations',
      data: {'name': name},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> list() async {
    final res = await _client.get('/api/organizations');
    return res.data as List<dynamic>;
  }
}
