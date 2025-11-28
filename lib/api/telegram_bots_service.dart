import 'package:messenger_flutter/api/api_client.dart';
import 'package:messenger_flutter/models/telegram_bot_models.dart';

class TelegramBotsService {
  final ApiClient _client;
  TelegramBotsService(this._client);

  /// Получить список ботов организации
  /// GET /api/telegram/organizations/:organizationId/bots
  Future<TelegramBotsListResponse> listBots(int organizationId) async {
    final res = await _client.get(
      '/api/telegram/organizations/$organizationId/bots',
    );
    return TelegramBotsListResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// Получить информацию о конкретном боте
  /// GET /api/telegram/bots/:botId
  Future<TelegramBotResponse> getBot(int botId) async {
    final res = await _client.get('/api/telegram/bots/$botId');
    return TelegramBotResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// Создать нового бота
  /// POST /api/telegram/organizations/:organizationId/bots
  Future<TelegramBotResponse> createBot({
    required int organizationId,
    required String botToken,
    String? welcomeMessage,
    bool? autoStart,
    bool? autoReply,
    String? webhookUrl,
  }) async {
    final res = await _client.postJson(
      '/api/telegram/organizations/$organizationId/bots',
      data: {
        'botToken': botToken,
        if (welcomeMessage != null) 'welcomeMessage': welcomeMessage,
        if (autoStart != null) 'autoStart': autoStart,
        if (autoReply != null) 'autoReply': autoReply,
        if (webhookUrl != null) 'webhookUrl': webhookUrl,
      },
    );
    return TelegramBotResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// Обновить бота
  /// PUT /api/telegram/bots/:botId
  Future<TelegramBotResponse> updateBot({
    required int botId,
    String? botToken,
    String? welcomeMessage,
    bool? autoReply,
    String? webhookUrl,
  }) async {
    final res = await _client.postJson(
      '/api/telegram/bots/$botId',
      data: {
        if (botToken != null) 'botToken': botToken,
        if (welcomeMessage != null) 'welcomeMessage': welcomeMessage,
        if (autoReply != null) 'autoReply': autoReply,
        if (webhookUrl != null) 'webhookUrl': webhookUrl,
      },
    );
    return TelegramBotResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// Удалить бота
  /// DELETE /api/telegram/bots/:botId
  Future<Map<String, dynamic>> deleteBot(int botId) async {
    final res = await _client.delete('/api/telegram/bots/$botId');
    return res.data as Map<String, dynamic>;
  }

  /// Запустить бота
  /// POST /api/telegram/bots/:botId/start
  Future<Map<String, dynamic>> startBot(int botId) async {
    final res = await _client.postJson('/api/telegram/bots/$botId/start');
    return res.data as Map<String, dynamic>;
  }

  /// Остановить бота
  /// POST /api/telegram/bots/:botId/stop
  Future<Map<String, dynamic>> stopBot(int botId) async {
    final res = await _client.postJson('/api/telegram/bots/$botId/stop');
    return res.data as Map<String, dynamic>;
  }

  /// Отправить сообщение через бота
  /// POST /api/telegram/bots/:botId/messages
  Future<TelegramMessageResponse> sendMessage({
    required int botId,
    required String chatId,
    required String content,
    int? replyToMessageId,
  }) async {
    final res = await _client.postJson(
      '/api/telegram/bots/$botId/messages',
      data: {
        'chatId': chatId,
        'content': content,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      },
    );
    return TelegramMessageResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// Получить чаты бота
  /// GET /api/telegram/bots/:botId/chats
  Future<TelegramChatsListResponse> getChats({
    required int botId,
    int? limit,
    int? offset,
    String? status, // new | open | in_progress | resolved | closed
  }) async {
    final res = await _client.get(
      '/api/telegram/bots/$botId/chats',
      query: {
        if (limit != null) 'limit': limit.toString(),
        if (offset != null) 'offset': offset.toString(),
        if (status != null) 'status': status,
      },
    );
    return TelegramChatsListResponse.fromJson(res.data as Map<String, dynamic>);
  }
}
