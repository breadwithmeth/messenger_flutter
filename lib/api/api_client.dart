import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:typed_data';

/// Базовый HTTP клиент поверх Dio с автоматическим подставлением JWT и
/// обработкой ошибок.
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  /// Базовый URL сервера, например http://localhost:3000
  final String baseUrl;

  static const _tokenKey = 'auth_token';

  ApiClient({required this.baseUrl, Dio? dio, FlutterSecureStorage? storage})
    : _dio = dio ?? Dio(),
      _storage = storage ?? const FlutterSecureStorage() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Interceptor: добавляет Authorization заголовок если токен есть
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (e, handler) {
          // Можно централизованно мапить ошибки
          return handler.next(e);
        },
      ),
    );
  }

  // ===== Auth token mgmt =====
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  // ===== Low-level methods =====
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) {
    return _dio.get<T>(path, queryParameters: query);
  }

  Future<Response<T>> postJson<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) {
    return _dio.post<T>(path, data: data, queryParameters: query);
  }

  Future<Response<T>> postForm<T>(String path, FormData formData) {
    return _dio.post<T>(path, data: formData);
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) {
    return _dio.delete<T>(path, data: data, queryParameters: query);
  }

  // Универсальная multipart загрузка, принимает сформированный MultipartFile
  Future<Response<T>> uploadMultipart<T>({
    required String path,
    required String fileFieldName,
    required MultipartFile filePart,
    Map<String, dynamic>? fields,
  }) async {
    final form = FormData.fromMap({
      fileFieldName: filePart,
      if (fields != null) ...fields,
    });
    return _dio.post<T>(path, data: form);
  }

  // Получение байтов по абсолютному или относительному URL (с учётом baseUrl)
  Future<Uint8List> getBytes(String urlOrPath) async {
    final resp = await _dio.get<List<int>>(
      urlOrPath,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = resp.data ?? const <int>[];
    return Uint8List.fromList(data);
  }
}
