import 'package:shared_preferences/shared_preferences.dart';

/// Глобальная конфигурация приложения.
/// Значение можно пробрасывать через --dart-define=API_BASE_URL=...
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    //defaultValue: 'https://bm.drawbridge.kz',
    defaultValue: 'http://localhost:4000',
  );

  // Ollama настройки (загружаются асинхронно)
  static Future<bool> isOllamaEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('ollama_enabled') ?? false;
  }

  static Future<String> getOllamaUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ollama_url') ?? 'http://localhost:11434';
  }

  static Future<String> getOllamaModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ollama_model') ?? 'llama2';
  }
}
