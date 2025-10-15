import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/models/chat_models.dart';

class ChatAssignmentService {
  final ApiClient _client;
  ChatAssignmentService(this._client);

  Future<Map<String, dynamic>> assign({
    required int chatId,
    required int operatorId,
    String? priority, // low|normal|high|urgent
  }) async {
    final res = await _client.postJson(
      '/api/chat-assignment/assign',
      data: {
        'chatId': chatId,
        'operatorId': operatorId,
        if (priority != null) 'priority': priority,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unassign({required int chatId}) async {
    final res = await _client.postJson(
      '/api/chat-assignment/unassign',
      data: {'chatId': chatId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<ChatsListResponse> myAssigned({
    DateTime? from,
    DateTime? to,
    String? status, // open|pending|closed
  }) async {
    final query = <String, dynamic>{
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      if (status != null) 'status': status,
    };
    final res = await _client.get(
      '/api/chat-assignment/my-assigned',
      query: query,
    );
    return ChatsListResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ChatsListResponse> unassigned({DateTime? from, DateTime? to}) async {
    final query = <String, dynamic>{
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final res = await _client.get(
      '/api/chat-assignment/unassigned',
      query: query,
    );
    return ChatsListResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> setPriority({
    required int chatId,
    required String priority,
  }) async {
    final res = await _client.postJson(
      '/api/chat-assignment/priority',
      data: {'chatId': chatId, 'priority': priority},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> close({
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
