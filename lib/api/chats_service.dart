import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/models/chat_models.dart';

class ChatsService {
  final ApiClient _client;
  ChatsService(this._client);

  Future<ChatsListResponse> listChats({
    ChatFilters? filters,
    String?
    sortBy, // lastMessageAt | createdAt | priority | unreadCount | ticketNumber | status | name
    String? sortOrder, // desc | asc
  }) async {
    final query = <String, dynamic>{};

    // Добавляем параметры из фильтров
    if (filters != null) {
      query.addAll(filters.toQueryParams());
    }

    // Добавляем параметры сортировки
    if (sortBy != null) query['sortBy'] = sortBy;
    if (sortOrder != null) query['sortOrder'] = sortOrder;

    final res = await _client.get('/api/chats', query: query);
    return ChatsListResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MessagesResponse> chatMessages(int chatId) async {
    final res = await _client.get('/api/chats/$chatId/messages');
    return MessagesResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> assignChat(
    int chatId,
    int userId, {
    String priority = 'normal',
  }) async {
    await _client.postJson(
      '/api/chat-assignment/assign',
      data: {'chatId': chatId, 'operatorId': userId, 'priority': priority},
    );
  }

  Future<List<dynamic>> getOperators() async {
    final res = await _client.get('/api/users/all');
    return res.data as List<dynamic>;
  }

  Future<ChatProfileResponse> getChatProfile({
    required String remoteJid,
    required int organizationPhoneId,
  }) async {
    final res = await _client.get(
      '/api/chats/$remoteJid/profile',
      query: {'organizationPhoneId': organizationPhoneId.toString()},
    );
    return ChatProfileResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> changePriority({
    required int chatId,
    required String priority,
  }) async {
    final res = await _client.postJson(
      '/api/chat-assignment/priority',
      data: {'chatId': chatId, 'priority': priority},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeChat({
    required int chatId,
    String? reason,
  }) async {
    final res = await _client.postJson(
      '/api/chat-assignment/close',
      data: {'chatId': chatId, if (reason != null) 'reason': reason},
    );
    return res.data as Map<String, dynamic>;
  }
}
