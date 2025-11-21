import 'package:messenger_flutter/api/api_client.dart';

class MessagesService {
  final ApiClient _client;
  MessagesService(this._client);

  Future<Map<String, dynamic>> sendText({
    required int organizationPhoneId,
    required String receiverJid,
    required String text,
  }) async {
    final res = await _client.postJson(
      '/api/messages/send-text',
      data: {
        'organizationPhoneId': organizationPhoneId,
        'receiverJid': receiverJid,
        'text': text,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMedia({
    required int organizationPhoneId,
    required String receiverJid,
    required String mediaType, // image|video|document|audio
    required String mediaPath,
    String? caption,
    String? filename,
  }) async {
    final data = {
      'organizationPhoneId': organizationPhoneId,
      'receiverJid': receiverJid,
      'mediaType': mediaType,
      'mediaPath': mediaPath,
      if (caption != null) 'caption': caption,
      if (filename != null) 'filename': filename,
    };
    final res = await _client.postJson('/api/messages/send-media', data: data);
    return res.data as Map<String, dynamic>;
  }

  /// Отправить текстовое сообщение по номеру тикета
  Future<Map<String, dynamic>> sendByTicket({
    required int ticketNumber,
    required String text,
  }) async {
    final res = await _client.postJson(
      '/api/messages/send-by-ticket',
      data: {'ticketNumber': ticketNumber, 'text': text},
    );
    return res.data as Map<String, dynamic>;
  }
}
