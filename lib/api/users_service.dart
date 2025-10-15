import 'package:messenger_flutter/api/api_client.dart';

class UsersService {
  final ApiClient _client;
  UsersService(this._client);

  Future<Map<String, dynamic>> create({
    required String email,
    required String password,
    required String name,
    String? role,
  }) async {
    final res = await _client.postJson(
      '/api/users',
      data: {
        'email': email,
        'password': password,
        'name': name,
        if (role != null) 'role': role,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> all() async {
    final res = await _client.get('/api/users/all');
    return res.data as List<dynamic>;
  }
}
