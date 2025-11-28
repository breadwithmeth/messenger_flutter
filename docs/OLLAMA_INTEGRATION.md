# Интеграция Ollama

## Описание

Добавлена страница настроек для подключения к локальному AI-серверу Ollama. Теперь вы можете использовать большие языковые модели прямо в приложении.

## Что добавлено

### 1. Страница настроек (`lib/screens/settings_page.dart`)
- Включение/выключение Ollama
- Настройка URL сервера (по умолчанию: `http://localhost:11434`)
- Выбор модели (по умолчанию: `llama2`)
- Проверка подключения к серверу
- Просмотр списка доступных моделей

### 2. Сервис Ollama (`lib/api/ollama_service.dart`)
- `testConnection()` - проверка доступности сервера
- `getModels()` - получение списка установленных моделей
- `generate()` - отправка запроса к модели
- `generateStream()` - потоковая генерация ответов

### 3. Обновленная конфигурация (`lib/config.dart`)
Добавлены методы для работы с настройками Ollama:
- `isOllamaEnabled()` - проверка, включена ли Ollama
- `getOllamaUrl()` - получение URL сервера
- `getOllamaModel()` - получение выбранной модели

### 4. Навигация
Добавлен пункт "Настройки" в боковое меню приложения.

## Как использовать

### 1. Установка Ollama
```bash
# macOS/Linux
curl https://ollama.ai/install.sh | sh

# Или скачайте с сайта
# https://ollama.ai
```

### 2. Запуск Ollama

#### Для десктопного приложения (без CORS проблем)
```bash
# Запустить сервер
ollama serve

# Загрузить модель (в другом терминале)
ollama pull llama2
# или другую модель, например:
ollama pull mistral
ollama pull codellama
```

#### Для веб-приложения (с поддержкой CORS)

**macOS:**
```bash
# Остановите текущий ollama, если запущен
pkill ollama

# Запустите с поддержкой CORS
OLLAMA_ORIGINS="*" ollama serve

# Или для конкретного домена
OLLAMA_ORIGINS="https://yourdomain.com" ollama serve
```

**Linux:**
```bash
# Остановите сервис
sudo systemctl stop ollama

# Создайте или отредактируйте файл с переменными окружения
sudo mkdir -p /etc/systemd/system/ollama.service.d
echo '[Service]' | sudo tee /etc/systemd/system/ollama.service.d/environment.conf
echo 'Environment="OLLAMA_ORIGINS=*"' | sudo tee -a /etc/systemd/system/ollama.service.d/environment.conf

# Перезагрузите конфигурацию и запустите
sudo systemctl daemon-reload
sudo systemctl start ollama
```

**Windows:**
```powershell
# Остановите Ollama, если запущен
# Затем в PowerShell с правами администратора:
[Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "Machine")

# Перезапустите Ollama
```

**Альтернатива - использовать прокси:**
Если вы не можете изменить настройки Ollama, используйте прокси-сервер с CORS поддержкой между веб-приложением и Ollama.

### 3. Настройка в приложении
1. Откройте приложение
2. Перейдите в меню (☰) → Настройки
3. Включите переключатель "Включить Ollama"
4. Укажите URL сервера (по умолчанию уже указан `http://localhost:11434`)
5. Укажите название модели (например, `llama2`)
6. Нажмите "Проверить подключение"
7. Если подключение успешно, вы увидите список доступных моделей
8. Нажмите "Сохранить" (иконка дискеты в верхнем правом углу)

### 4. Использование в коде
```dart
import '../config.dart';
import '../api/ollama_service.dart';

// Проверяем, включена ли Ollama
final enabled = await AppConfig.isOllamaEnabled();

if (enabled) {
  final service = OllamaService();
  
  // Простой запрос
  final response = await service.generate(
    prompt: 'Объясни что такое Flutter',
  );
  print(response);
  
  // Потоковый запрос
  await for (final chunk in service.generateStream(
    prompt: 'Напиши код на Dart',
  )) {
    print(chunk);
  }
}
```

## Настройки хранятся в SharedPreferences
- `ollama_enabled` - включена ли Ollama (bool)
- `ollama_url` - URL сервера (String)
- `ollama_model` - название модели (String)

## Популярные модели Ollama
- `llama2` - универсальная модель от Meta
- `mistral` - эффективная модель для общих задач
- `codellama` - специализирована для кода
- `phi` - компактная модель от Microsoft
- `gemma` - модель от Google

Полный список: https://ollama.ai/library

## Примечания
- Убедитесь, что Ollama сервер запущен перед использованием
- Модели требуют значительного объема памяти (4-8GB+)
- Первый запрос может занять время из-за загрузки модели в память
- Рекомендуется использовать на устройствах с хорошей производительностью

## Решение проблем

### Ошибка 403 Forbidden при подключении с веб-приложения
Это проблема CORS. Решение:
1. Убедитесь, что Ollama запущен с переменной окружения `OLLAMA_ORIGINS`
2. Проверьте, что используете правильный URL (для локальной разработки используйте `http://127.0.0.1:11434` вместо `localhost`)
3. Для продакшена укажите конкретный домен: `OLLAMA_ORIGINS="https://yourdomain.com"`

### Ollama не отвечает
1. Проверьте, что сервис запущен: `ps aux | grep ollama`
2. Проверьте доступность: `curl http://127.0.0.1:11434/api/tags`
3. Перезапустите сервис

### Модель возвращает странные ответы
1. Используйте более простые промпты для маленьких моделей
2. Попробуйте другую модель (например, `mistral` вместо `phi`)
3. Убедитесь, что модель полностью загружена: `ollama list`
