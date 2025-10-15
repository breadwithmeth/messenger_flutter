import 'package:dio/dio.dart';
import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/models/auth_models.dart';

class AuthService {
  final ApiClient _client;
  AuthService(this._client);

  Future<LoginResponse> login(LoginRequest req) async {
    final res = await _client.postJson('/api/auth/login', data: req.toJson());
    final data = res.data as Map<String, dynamic>;
    final parsed = LoginResponse.fromJson(data);
    await _client.saveToken(parsed.token);
    return parsed;
  }

  Future<void> logout() => _client.clearToken();

  Future<UserDto> me() async {
    final Response res = await _client.get('/api/users/me');
    return UserDto.fromJson(res.data as Map<String, dynamic>);
  }
}
