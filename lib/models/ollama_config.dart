import 'package:shared_preferences/shared_preferences.dart';

class OllamaConfig {
  static const String _keyEnabled = 'ollama_enabled';
  static const String _keyBaseUrl = 'ollama_base_url';
  static const String _keyModel = 'ollama_model';
  static const String _keyApiKey = 'ollama_api_key';

  bool enabled;
  String baseUrl;
  String model;
  String? apiKey;

  OllamaConfig({
    this.enabled = false,
    this.baseUrl = 'http://localhost:11434',
    this.model = 'llama2',
    this.apiKey,
  });

  // Сохранить конфигурацию
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    await prefs.setString(_keyBaseUrl, baseUrl);
    await prefs.setString(_keyModel, model);
    if (apiKey != null) {
      await prefs.setString(_keyApiKey, apiKey!);
    } else {
      await prefs.remove(_keyApiKey);
    }
  }

  // Загрузить конфигурацию
  static Future<OllamaConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return OllamaConfig(
      enabled: prefs.getBool(_keyEnabled) ?? false,
      baseUrl: prefs.getString(_keyBaseUrl) ?? 'http://localhost:11434',
      model: prefs.getString(_keyModel) ?? 'llama2',
      apiKey: prefs.getString(_keyApiKey),
    );
  }

  // Очистить конфигурацию
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEnabled);
    await prefs.remove(_keyBaseUrl);
    await prefs.remove(_keyModel);
    await prefs.remove(_keyApiKey);
  }
}
