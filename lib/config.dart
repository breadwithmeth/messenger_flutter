/// Глобальная конфигурация приложения.
/// Значение можно пробрасывать через --dart-define=API_BASE_URL=...
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bm.drawbridge.kz',
    //defaultValue: 'http://localhost:4000',
  );
}
