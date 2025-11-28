import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/tickets_service.dart';
import '../models/ticket_models.dart';
import 'dart:async';

class TicketDetailPane extends StatefulWidget {
  final ApiClient client;
  final TicketDto ticket;

  const TicketDetailPane({
    super.key,
    required this.client,
    required this.ticket,
  });

  @override
  State<TicketDetailPane> createState() => _TicketDetailPaneState();
}

class _TicketDetailPaneState extends State<TicketDetailPane> {
  late final TicketsService _tickets;
  TicketDto? _currentTicket;
  List<TicketHistoryDto> _history = [];
  bool _loading = false;
  String? _error;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _tickets = TicketsService(widget.client);
    _currentTicket = widget.ticket;
    _loadTicketDetails();
    _startPolling();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted) return;
      if (_loading) return;
      try {
        await _loadTicketDetails();
      } catch (_) {
        // мягко игнорируем ошибки опроса
      }
    });
  }

  Future<void> _loadTicketDetails() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ticket = await _tickets.getTicketByNumber(
        widget.ticket.ticketNumber,
      );
      final history = await _tickets.getHistory(widget.ticket.ticketNumber);
      if (mounted) {
        setState(() {
          _currentTicket = ticket;
          _history = history;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTicket == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _error != null
                ? _buildError()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 16),
                        _buildClientCard(),
                        const SizedBox(height: 16),
                        _buildTagsCard(),
                        const SizedBox(height: 16),
                        _buildHistoryCard(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.confirmation_number,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Тикет #${_currentTicket!.ticketNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_currentTicket!.subject?.isNotEmpty == true)
                      Text(
                        _currentTicket!.subject!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
              ),
              if (_loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(_currentTicket!.status),
              _priorityChip(_currentTicket!.priority),
              if (_currentTicket!.category?.isNotEmpty == true)
                _categoryChip(_currentTicket!.category!),
              if (_currentTicket!.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mark_email_unread,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentTicket!.unreadCount} непрочит.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Информация',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _infoRow(
              'Назначен',
              _currentTicket!.assignedUser?.name ?? 'Не назначен',
            ),
            const SizedBox(height: 12),
            _infoRow(
              'Создан',
              _currentTicket!.createdAt != null
                  ? _formatDateTime(_currentTicket!.createdAt!)
                  : '—',
            ),
            const SizedBox(height: 12),
            _infoRow(
              'Обновлён',
              _currentTicket!.updatedAt != null
                  ? _formatDateTime(_currentTicket!.updatedAt!)
                  : '—',
            ),
            if (_currentTicket!.resolvedAt != null) ...[
              const SizedBox(height: 12),
              _infoRow('Решён', _formatDateTime(_currentTicket!.resolvedAt!)),
            ],
            if (_currentTicket!.closedAt != null) ...[
              const SizedBox(height: 12),
              _infoRow('Закрыт', _formatDateTime(_currentTicket!.closedAt!)),
            ],
            if (_currentTicket!.customerRating != null) ...[
              const SizedBox(height: 12),
              _infoRow('Оценка', '⭐ ${_currentTicket!.customerRating}/5'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard() {
    if (_currentTicket!.client == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Клиент',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_currentTicket!.client!.name?.isNotEmpty == true)
              _infoRow('Имя', _currentTicket!.client!.name!),
            if (_currentTicket!.client!.name?.isNotEmpty == true)
              const SizedBox(height: 12),
            _infoRow('Телефон', _currentTicket!.client!.phoneJid),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsCard() {
    if (_currentTicket!.tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.label_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Теги',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentTicket!.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'История',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_history.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'История пуста',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ..._history.map((h) => _buildHistoryItem(h)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(TicketHistoryDto history) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getHistoryTypeLabel(history.changeType),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (history.description.isNotEmpty)
                  Text(
                    history.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                if (history.oldValue != null || history.newValue != null)
                  Text(
                    '${history.oldValue ?? "—"} → ${history.newValue ?? "—"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (history.createdAt != null)
                  Text(
                    _formatDateTime(history.createdAt!),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTicketDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'new':
        color = Colors.blue.shade100;
        icon = Icons.new_releases_outlined;
        label = 'Новый';
        break;
      case 'open':
        color = Colors.green.shade100;
        icon = Icons.check_circle_outline;
        label = 'Открыт';
        break;
      case 'in_progress':
        color = Colors.lightBlue.shade100;
        icon = Icons.autorenew;
        label = 'В работе';
        break;
      case 'pending':
        color = Colors.orange.shade100;
        icon = Icons.pending_outlined;
        label = 'В ожидании';
        break;
      case 'resolved':
        color = Colors.lightGreen.shade100;
        icon = Icons.done_all;
        label = 'Решён';
        break;
      case 'closed':
        color = Colors.grey.shade200;
        icon = Icons.cancel_outlined;
        label = 'Закрыт';
        break;
      default:
        color = Colors.blue.shade100;
        icon = Icons.info_outline;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _priorityChip(String priority) {
    Color color;
    String label;

    switch (priority) {
      case 'urgent':
        color = Colors.red.shade100;
        label = 'Срочный';
        break;
      case 'high':
        color = Colors.orange.shade100;
        label = 'Высокий';
        break;
      case 'normal':
        color = Colors.blue.shade100;
        label = 'Обычный';
        break;
      case 'low':
        color = Colors.grey.shade200;
        label = 'Низкий';
        break;
      default:
        color = Colors.grey.shade200;
        label = priority;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _categoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.category_outlined,
            size: 14,
            color: Colors.purple.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            category,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.purple.shade900,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);

    if (diff.inDays == 0) {
      return 'Сегодня в ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Вчера в ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else {
      return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getHistoryTypeLabel(String changeType) {
    switch (changeType) {
      case 'created':
        return 'Создан';
      case 'status_changed':
        return 'Статус изменён';
      case 'priority_changed':
        return 'Приоритет изменён';
      case 'assigned':
        return 'Назначен оператор';
      case 'unassigned':
        return 'Снято назначение';
      case 'tag_added':
        return 'Добавлен тег';
      case 'tag_removed':
        return 'Удалён тег';
      case 'note_added':
        return 'Добавлена заметка';
      default:
        return changeType;
    }
  }
}
