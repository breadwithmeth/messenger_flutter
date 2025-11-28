import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/models/chat_models.dart';

class ChatsService {
  final ApiClient _client;
  ChatsService(this._client);

  Future<ChatsListResponse> listChats({
    String? status, // open | pending | closed
    String? assigned, // 'true' | 'false'
    String? priority, // low | normal | high | urgent
    String?
    sortBy, // lastMessageAt | createdAt | priority | unreadCount | ticketNumber | status | name
    String? sortOrder, // desc | asc
  }) async {
    final res = await _client.get(
      '/api/chats',
      query: {
        if (status != null) 'status': status,
        if (assigned != null) 'assigned': assigned,
        if (priority != null) 'priority': priority,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
    );
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
}
