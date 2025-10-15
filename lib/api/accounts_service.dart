import 'package:messenger_flutter/api/api_client.dart';

class AccountsService {
  final ApiClient _client;
  AccountsService(this._client);

  Future<Map<String, dynamic>> createAccount({
    required String phoneJid,
    required String displayName,
  }) async {
    final res = await _client.postJson(
      '/api/accounts',
      data: {'phoneJid': phoneJid, 'displayName': displayName},
    );
    return res.data as Map<String, dynamic>;
  }
}

class OrganizationPhonesService {
  final ApiClient _client;
  OrganizationPhonesService(this._client);

  Future<Map<String, dynamic>> create({
    required String phoneJid,
    required String displayName,
  }) async {
    final res = await _client.postJson(
      '/api/organization-phones',
      data: {'phoneJid': phoneJid, 'displayName': displayName},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> all() async {
    final res = await _client.get('/api/organization-phones/all');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> connect(int organizationPhoneId) async {
    final res = await _client.postJson(
      '/api/organization-phones/$organizationPhoneId/connect',
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> disconnect(int organizationPhoneId) async {
    await _client.delete(
      '/api/organization-phones/$organizationPhoneId/disconnect',
    );
  }
}
