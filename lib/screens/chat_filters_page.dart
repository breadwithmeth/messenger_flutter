import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:messenger_flutter/models/chat_models.dart';

class ChatFiltersPage extends StatefulWidget {
  final ChatFilters? initialFilters;

  const ChatFiltersPage({super.key, this.initialFilters});

  @override
  State<ChatFiltersPage> createState() => _ChatFiltersPageState();
}

class _ChatFiltersPageState extends State<ChatFiltersPage> {
  String? _selectedStatus;
  bool? _selectedAssigned;
  String? _selectedPriority;
  bool _includeProfile = true;

  final List<String> _statuses = ['open', 'pending', 'closed'];
  final List<String> _priorities = ['low', 'normal', 'high', 'urgent'];

  @override
  void initState() {
    super.initState();
    if (widget.initialFilters != null) {
      _selectedStatus = widget.initialFilters!.status;
      _selectedAssigned = widget.initialFilters!.assigned;
      _selectedPriority = widget.initialFilters!.priority;
      _includeProfile = widget.initialFilters!.includeProfile ?? true;
    }
  }

  Future<void> _saveFilters() async {
    final filters = ChatFilters(
      status: _selectedStatus,
      assigned: _selectedAssigned,
      priority: _selectedPriority,
      includeProfile: _includeProfile,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_filters', jsonEncode(filters.toJson()));

    if (mounted) {
      Navigator.of(context).pop(filters);
    }
  }

  Future<void> _resetFilters() async {
    setState(() {
      _selectedStatus = null;
      _selectedAssigned = null;
      _selectedPriority = null;
      _includeProfile = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_filters');

    if (mounted) {
      Navigator.of(context).pop(ChatFilters(includeProfile: true));
    }
  }

  String _getStatusLabel(String? status) {
    if (status == null) return 'Все';
    switch (status) {
      case 'open':
        return 'Открытые';
      case 'pending':
        return 'В ожидании';
      case 'closed':
        return 'Закрытые';
      default:
        return status;
    }
  }

  String _getAssignedLabel(bool? assigned) {
    if (assigned == null) return 'Все';
    return assigned ? 'Назначенные' : 'Неназначенные';
  }

  String _getPriorityLabel(String? priority) {
    if (priority == null) return 'Все';
    switch (priority) {
      case 'low':
        return 'Низкий';
      case 'normal':
        return 'Обычный';
      case 'high':
        return 'Высокий';
      case 'urgent':
        return 'Срочный';
      default:
        return priority;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Фильтры чатов'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Сбросить'),
          onPressed: _resetFilters,
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            // Статус
            CupertinoFormSection.insetGrouped(
              header: const Text('СТАТУС'),
              children: [
                CupertinoFormRow(
                  prefix: const Text('Статус'),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (context) => CupertinoActionSheet(
                          title: const Text('Выберите статус'),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                setState(() => _selectedStatus = null);
                                Navigator.pop(context);
                              },
                              child: const Text('Все'),
                            ),
                            ..._statuses.map((status) {
                              return CupertinoActionSheetAction(
                                onPressed: () {
                                  setState(() => _selectedStatus = status);
                                  Navigator.pop(context);
                                },
                                child: Text(_getStatusLabel(status)),
                              );
                            }),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Отмена'),
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _getStatusLabel(_selectedStatus),
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chevron_forward,
                          size: 16,
                          color: CupertinoColors.systemGrey3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Назначение
            CupertinoFormSection.insetGrouped(
              header: const Text('НАЗНАЧЕНИЕ'),
              children: [
                CupertinoFormRow(
                  prefix: const Text('Назначение'),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (context) => CupertinoActionSheet(
                          title: const Text('Назначение'),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                setState(() => _selectedAssigned = null);
                                Navigator.pop(context);
                              },
                              child: const Text('Все'),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {
                                setState(() => _selectedAssigned = true);
                                Navigator.pop(context);
                              },
                              child: const Text('Назначенные'),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {
                                setState(() => _selectedAssigned = false);
                                Navigator.pop(context);
                              },
                              child: const Text('Неназначенные'),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Отмена'),
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _getAssignedLabel(_selectedAssigned),
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chevron_forward,
                          size: 16,
                          color: CupertinoColors.systemGrey3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Приоритет
            CupertinoFormSection.insetGrouped(
              header: const Text('ПРИОРИТЕТ'),
              children: [
                CupertinoFormRow(
                  prefix: const Text('Приоритет'),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (context) => CupertinoActionSheet(
                          title: const Text('Выберите приоритет'),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                setState(() => _selectedPriority = null);
                                Navigator.pop(context);
                              },
                              child: const Text('Все'),
                            ),
                            ..._priorities.map((priority) {
                              return CupertinoActionSheetAction(
                                onPressed: () {
                                  setState(() => _selectedPriority = priority);
                                  Navigator.pop(context);
                                },
                                child: Text(_getPriorityLabel(priority)),
                              );
                            }),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Отмена'),
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _getPriorityLabel(_selectedPriority),
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chevron_forward,
                          size: 16,
                          color: CupertinoColors.systemGrey3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Включить профили
            CupertinoFormSection.insetGrouped(
              header: const Text('ДОПОЛНИТЕЛЬНО'),
              children: [
                CupertinoFormRow(
                  prefix: const Text('Показывать профили'),
                  child: CupertinoSwitch(
                    value: _includeProfile,
                    onChanged: (value) {
                      setState(() => _includeProfile = value);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Кнопка применить
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoButton.filled(
                onPressed: _saveFilters,
                child: const Text('Применить фильтры'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
