import 'package:messenger_flutter/api/api_client.dart';

class UnreadService {
  final ApiClient _client;
  UnreadService(this._client);

  Future<Map<String, dynamic>> markRead(
    int chatId, {
    List<int>? messageIds,
  }) async {
    final res = await _client.postJson(
      '/api/unread/$chatId/mark-read',
      data: messageIds != null ? {'messageIds': messageIds} : null,
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markChatRead(int chatId) async {
    final res = await _client.postJson('/api/unread/$chatId/mark-chat-read');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> counts() async {
    final res = await _client.get('/api/unread/counts');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> chats({bool? assignedOnly}) async {
    final res = await _client.get(
      '/api/unread/chats',
      query: {
        if (assignedOnly != null) 'assignedOnly': assignedOnly.toString(),
      },
    );
    return res.data as List<dynamic>;
  }
}
