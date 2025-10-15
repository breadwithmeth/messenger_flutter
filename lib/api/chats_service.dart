import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/models/chat_models.dart';

class ChatsService {
  final ApiClient _client;
  ChatsService(this._client);

  Future<ChatsListResponse> listChats({
    String? status, // open | pending | closed
    String? assigned, // 'true' | 'false'
    String? priority, // low | normal | high | urgent
  }) async {
    final res = await _client.get(
      '/api/chats',
      query: {
        if (status != null) 'status': status,
        if (assigned != null) 'assigned': assigned,
        if (priority != null) 'priority': priority,
      },
    );
    return ChatsListResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MessagesResponse> chatMessages(int chatId) async {
    final res = await _client.get('/api/chats/$chatId/messages');
    return MessagesResponse.fromJson(res.data as Map<String, dynamic>);
  }
}
