import 'package:dio/dio.dart';
import '../config.dart';

class OllamaService {
  final Dio _dio;

  OllamaService() : _dio = Dio();

  /// Проверяет доступность Ollama сервера
  Future<bool> testConnection(String baseUrl) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/tags',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Ошибка подключения к Ollama: $e');
      return false;
    }
  }

  /// Получает список доступных моделей
  Future<List<String>> getModels(String baseUrl) async {
    try {
      final response = await _dio.get('$baseUrl/api/tags');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final models = data['models'] as List<dynamic>?;
        if (models != null) {
          return models.map((m) => m['name'] as String).toList();
        }
      }
    } catch (e) {
      print('Ошибка получения моделей: $e');
    }
    return [];
  }

  /// Отправляет запрос к модели Ollama
  Future<String?> generate({
    required String prompt,
    String? model,
    String? baseUrl,
  }) async {
    try {
      final url = baseUrl ?? await AppConfig.getOllamaUrl();
      final selectedModel = model ?? await AppConfig.getOllamaModel();

      final response = await _dio.post(
        '$url/api/generate',
        data: {'model': selectedModel, 'prompt': prompt, 'stream': false},
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['response'] as String?;
      }
    } catch (e) {
      print('Ошибка генерации ответа: $e');
    }
    return null;
  }

  /// Отправляет запрос к модели с потоковой передачей данных
  Stream<String> generateStream({
    required String prompt,
    String? model,
    String? baseUrl,
  }) async* {
    try {
      final url = baseUrl ?? await AppConfig.getOllamaUrl();
      final selectedModel = model ?? await AppConfig.getOllamaModel();

      final response = await _dio.post(
        '$url/api/generate',
        data: {'model': selectedModel, 'prompt': prompt, 'stream': true},
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200) {
        final stream = response.data.stream as Stream<List<int>>;
        await for (final chunk in stream) {
          final text = String.fromCharCodes(chunk);
          // Парсим JSON строки
          final lines = text.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              try {
                final json = response.data;
                if (json is Map<String, dynamic>) {
                  final responseText = json['response'] as String?;
                  if (responseText != null) {
                    yield responseText;
                  }
                }
              } catch (e) {
                // Игнорируем ошибки парсинга
              }
            }
          }
        }
      }
    } catch (e) {
      print('Ошибка потоковой генерации: $e');
    }
  }
}
