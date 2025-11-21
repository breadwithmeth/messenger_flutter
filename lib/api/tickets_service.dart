import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/models/ticket_models.dart';

class TicketsService {
  final ApiClient _client;
  TicketsService(this._client);

  /// Получить список тикетов
  Future<TicketListResponse> getTickets({
    String? status,
    String? priority,
    int? assignedUserId,
    String? category,
    int page = 1,
    int limit = 20,
    String sortBy = 'updatedAt',
    String sortOrder = 'desc',
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };

    if (status != null) {
      queryParams['status'] = status;
    }
    if (priority != null) {
      queryParams['priority'] = priority;
    }
    if (assignedUserId != null) {
      queryParams['assignedUserId'] = assignedUserId.toString();
    }
    if (category != null) {
      queryParams['category'] = category;
    }

    final res = await _client.get('/api/tickets', query: queryParams);
    return TicketListResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// Получить тикет по номеру
  Future<TicketDto> getTicketByNumber(int ticketNumber) async {
    final res = await _client.get('/api/tickets/$ticketNumber');
    return TicketDto.fromJson(res.data as Map<String, dynamic>);
  }

  /// Назначить тикет оператору
  Future<Map<String, dynamic>> assignTicket(
    int ticketNumber,
    int userId,
  ) async {
    final res = await _client.postJson(
      '/api/tickets/$ticketNumber/assign',
      data: {'userId': userId},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Снять назначение с тикета
  Future<Map<String, dynamic>> unassignTicket(int ticketNumber) async {
    final res = await _client.postJson('/api/tickets/$ticketNumber/unassign');
    return res.data as Map<String, dynamic>;
  }

  /// Изменить статус тикета
  Future<Map<String, dynamic>> changeStatus(
    int ticketNumber,
    String status, {
    String? reason,
  }) async {
    final res = await _client.postJson(
      '/api/tickets/$ticketNumber/status',
      data: {'status': status, if (reason != null) 'reason': reason},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Изменить приоритет тикета
  Future<Map<String, dynamic>> changePriority(
    int ticketNumber,
    String priority,
  ) async {
    final res = await _client.postJson(
      '/api/tickets/$ticketNumber/priority',
      data: {'priority': priority},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Добавить тег к тикету
  Future<Map<String, dynamic>> addTag(int ticketNumber, String tag) async {
    final res = await _client.postJson(
      '/api/tickets/$ticketNumber/tags',
      data: {'tag': tag},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Удалить тег из тикета
  Future<Map<String, dynamic>> removeTag(int ticketNumber, String tag) async {
    final res = await _client.delete('/api/tickets/$ticketNumber/tags/$tag');
    return res.data as Map<String, dynamic>;
  }

  /// Получить историю изменений тикета
  Future<List<TicketHistoryDto>> getHistory(int ticketNumber) async {
    final res = await _client.get('/api/tickets/$ticketNumber/history');
    final data = res.data as Map<String, dynamic>;
    return (data['history'] as List<dynamic>)
        .map((e) => TicketHistoryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Добавить внутреннюю заметку
  Future<Map<String, dynamic>> addNote(int ticketNumber, String note) async {
    final res = await _client.postJson(
      '/api/tickets/$ticketNumber/notes',
      data: {'note': note},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Получить статистику по тикетам
  Future<TicketStatsDto> getStats() async {
    final res = await _client.get('/api/tickets/stats');
    return TicketStatsDto.fromJson(res.data as Map<String, dynamic>);
  }

  /// Получить сообщения тикета
  Future<List<dynamic>> getMessages(int ticketNumber) async {
    final res = await _client.get('/api/tickets/$ticketNumber/messages');
    final data = res.data as Map<String, dynamic>;
    return data['messages'] as List<dynamic>;
  }
}
