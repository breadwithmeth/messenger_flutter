import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ollama_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _ollamaUrlController = TextEditingController();
  final _ollamaModelController = TextEditingController();
  final _ollamaService = OllamaService();
  bool _ollamaEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _ollamaEnabled = prefs.getBool('ollama_enabled') ?? false;
        _ollamaUrlController.text =
            prefs.getString('ollama_url') ?? 'http://localhost:11434';
        _ollamaModelController.text =
            prefs.getString('ollama_model') ?? 'llama2';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки настроек: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ollama_enabled', _ollamaEnabled);
      await prefs.setString('ollama_url', _ollamaUrlController.text.trim());
      await prefs.setString('ollama_model', _ollamaModelController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Настройки сохранены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    if (_ollamaUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите URL Ollama')));
      return;
    }

    setState(() => _isTesting = true);

    try {
      final url = _ollamaUrlController.text.trim();
      final isConnected = await _ollamaService.testConnection(url);

      if (!mounted) return;

      if (isConnected) {
        // Попробуем получить список моделей
        final models = await _ollamaService.getModels(url);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              models.isEmpty
                  ? 'Подключение успешно! Модели не найдены.'
                  : 'Подключение успешно! Найдено моделей: ${models.length}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Показываем диалог с доступными моделями
        if (models.isNotEmpty) {
          _showModelsDialog(models);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось подключиться к Ollama'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  void _showModelsDialog(List<String> models) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Доступные модели'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: models.length,
            itemBuilder: (context, index) {
              final model = models[index];
              final isCurrent = model == _ollamaModelController.text;
              return ListTile(
                title: Text(model),
                trailing: isCurrent
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    _ollamaModelController.text = model;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ollamaUrlController.dispose();
    _ollamaModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Сохранить',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.smart_toy,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Ollama',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Включить Ollama'),
                              subtitle: const Text(
                                'Использовать локальную AI модель для помощи',
                              ),
                              value: _ollamaEnabled,
                              onChanged: (value) {
                                setState(() => _ollamaEnabled = value);
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _ollamaUrlController,
                              enabled: _ollamaEnabled,
                              decoration: const InputDecoration(
                                labelText: 'URL Ollama сервера',
                                hintText: 'http://localhost:11434',
                                prefixIcon: Icon(Icons.link),
                                helperText: 'Адрес вашего Ollama API',
                              ),
                              validator: (value) {
                                if (_ollamaEnabled &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Укажите URL';
                                }
                                if (_ollamaEnabled &&
                                    !value!.startsWith(RegExp(r'https?://'))) {
                                  return 'URL должен начинаться с http:// или https://';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _ollamaModelController,
                              enabled: _ollamaEnabled,
                              decoration: const InputDecoration(
                                labelText: 'Модель',
                                hintText: 'llama2',
                                prefixIcon: Icon(Icons.model_training),
                                helperText:
                                    'Название модели (llama2, mistral, codellama и т.д.)',
                              ),
                              validator: (value) {
                                if (_ollamaEnabled &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Укажите название модели';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _ollamaEnabled && !_isTesting
                                    ? _testConnection
                                    : null,
                                icon: _isTesting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.wifi_tethering),
                                label: Text(
                                  _isTesting
                                      ? 'Проверка...'
                                      : 'Проверить подключение',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Убедитесь, что Ollama запущена и доступна по указанному адресу',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.7),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'О Ollama',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ollama позволяет запускать большие языковые модели локально на вашем устройстве.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Для установки посетите: ollama.ai',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
