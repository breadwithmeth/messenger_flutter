import 'package:messenger_flutter/api/api_client.dart';
import 'package:dio/dio.dart';

class MediaService {
  final ApiClient _client;
  MediaService(this._client);

  /// POST /api/media/send
  /// FormData: media: [file], chatId, mediaType, caption?
  Future<Map<String, dynamic>> uploadAndSend({
    required MultipartFile mediaPart,
    required int chatId,
    required String mediaType, // image|video|document|audio
    String? caption,
  }) async {
    final res = await _client.uploadMultipart(
      path: '/api/media/send',
      fileFieldName: 'media',
      filePart: mediaPart,
      fields: {
        'chatId': chatId,
        'mediaType': mediaType,
        if (caption != null) 'caption': caption,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// POST /api/media/upload
  Future<Map<String, dynamic>> uploadOnly({
    required MultipartFile mediaPart,
    required String mediaType,
  }) async {
    final res = await _client.uploadMultipart(
      path: '/api/media/upload',
      fileFieldName: 'media',
      filePart: mediaPart,
      fields: {'mediaType': mediaType},
    );
    return res.data as Map<String, dynamic>;
  }

  /// POST /api/media/send-by-chat
  Future<Map<String, dynamic>> sendByChat({
    required int chatId,
    required String mediaType,
    required String mediaPath, // URL или путь на сервере
    String? caption,
    String? filename,
  }) async {
    final res = await _client.postJson(
      '/api/media/send-by-chat',
      data: {
        'chatId': chatId,
        'mediaType': mediaType,
        'mediaPath': mediaPath,
        if (caption != null) 'caption': caption,
        if (filename != null) 'filename': filename,
      },
    );
    return res.data as Map<String, dynamic>;
  }
}
