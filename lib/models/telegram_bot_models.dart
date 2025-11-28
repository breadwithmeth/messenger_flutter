class TelegramBotDto {
  final int id;
  final int organizationId;
  final String botToken;
  final String? botUsername;
  final String? botName;
  final String status; // active | inactive | error
  final DateTime? lastActiveAt;
  final String? welcomeMessage;
  final bool? autoReply;
  final String? webhookUrl;
  final bool isRunning;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final TelegramOrganizationDto? organization;

  TelegramBotDto({
    required this.id,
    required this.organizationId,
    required this.botToken,
    this.botUsername,
    this.botName,
    required this.status,
    this.lastActiveAt,
    this.welcomeMessage,
    this.autoReply,
    this.webhookUrl,
    required this.isRunning,
    required this.createdAt,
    this.updatedAt,
    this.organization,
  });

  factory TelegramBotDto.fromJson(Map<String, dynamic> json) => TelegramBotDto(
    id: json['id'] as int,
    organizationId: json['organizationId'] as int,
    botToken: json['botToken'] as String,
    botUsername: json['botUsername'] as String?,
    botName: json['botName'] as String?,
    status: json['status'] as String? ?? 'inactive',
    lastActiveAt: json['lastActiveAt'] != null
        ? DateTime.tryParse(json['lastActiveAt'] as String)
        : null,
    welcomeMessage: json['welcomeMessage'] as String?,
    autoReply: json['autoReply'] as bool?,
    webhookUrl: json['webhookUrl'] as String?,
    isRunning: json['isRunning'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String)
        : null,
    organization: json['organization'] != null
        ? TelegramOrganizationDto.fromJson(
            json['organization'] as Map<String, dynamic>,
          )
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'organizationId': organizationId,
    'botToken': botToken,
    if (botUsername != null) 'botUsername': botUsername,
    if (botName != null) 'botName': botName,
    'status': status,
    if (lastActiveAt != null) 'lastActiveAt': lastActiveAt!.toIso8601String(),
    if (welcomeMessage != null) 'welcomeMessage': welcomeMessage,
    if (autoReply != null) 'autoReply': autoReply,
    if (webhookUrl != null) 'webhookUrl': webhookUrl,
    'isRunning': isRunning,
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (organization != null) 'organization': organization!.toJson(),
  };
}

class TelegramOrganizationDto {
  final int id;
  final String name;

  TelegramOrganizationDto({required this.id, required this.name});

  factory TelegramOrganizationDto.fromJson(Map<String, dynamic> json) =>
      TelegramOrganizationDto(
        id: json['id'] as int,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class TelegramChatDto {
  final int id;
  final String channel; // telegram
  final String? telegramChatId;
  final String? telegramUsername;
  final String? telegramFirstName;
  final String? telegramLastName;
  final String? name;
  final int? ticketNumber;
  final String status; // new | open | in_progress | resolved | closed
  final String priority; // low | medium | high | urgent
  final DateTime? lastMessageAt;
  final int unreadCount;
  final TelegramAssignedUserDto? assignedUser;
  final TelegramMessageCountDto? messageCount;

  TelegramChatDto({
    required this.id,
    required this.channel,
    this.telegramChatId,
    this.telegramUsername,
    this.telegramFirstName,
    this.telegramLastName,
    this.name,
    this.ticketNumber,
    required this.status,
    required this.priority,
    this.lastMessageAt,
    required this.unreadCount,
    this.assignedUser,
    this.messageCount,
  });

  factory TelegramChatDto.fromJson(Map<String, dynamic> json) =>
      TelegramChatDto(
        id: json['id'] as int,
        channel: json['channel'] as String? ?? 'telegram',
        telegramChatId: json['telegramChatId'] as String?,
        telegramUsername: json['telegramUsername'] as String?,
        telegramFirstName: json['telegramFirstName'] as String?,
        telegramLastName: json['telegramLastName'] as String?,
        name: json['name'] as String?,
        ticketNumber: json['ticketNumber'] as int?,
        status: json['status'] as String? ?? 'new',
        priority: json['priority'] as String? ?? 'medium',
        lastMessageAt: json['lastMessageAt'] != null
            ? DateTime.tryParse(json['lastMessageAt'] as String)
            : null,
        unreadCount: json['unreadCount'] as int? ?? 0,
        assignedUser: json['assignedUser'] != null
            ? TelegramAssignedUserDto.fromJson(
                json['assignedUser'] as Map<String, dynamic>,
              )
            : null,
        messageCount: json['_count'] != null
            ? TelegramMessageCountDto.fromJson(
                json['_count'] as Map<String, dynamic>,
              )
            : null,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'channel': channel,
    if (telegramChatId != null) 'telegramChatId': telegramChatId,
    if (telegramUsername != null) 'telegramUsername': telegramUsername,
    if (telegramFirstName != null) 'telegramFirstName': telegramFirstName,
    if (telegramLastName != null) 'telegramLastName': telegramLastName,
    if (name != null) 'name': name,
    if (ticketNumber != null) 'ticketNumber': ticketNumber,
    'status': status,
    'priority': priority,
    if (lastMessageAt != null)
      'lastMessageAt': lastMessageAt!.toIso8601String(),
    'unreadCount': unreadCount,
    if (assignedUser != null) 'assignedUser': assignedUser!.toJson(),
    if (messageCount != null) '_count': messageCount!.toJson(),
  };
}

class TelegramAssignedUserDto {
  final int id;
  final String? name;

  TelegramAssignedUserDto({required this.id, this.name});

  factory TelegramAssignedUserDto.fromJson(Map<String, dynamic> json) =>
      TelegramAssignedUserDto(
        id: json['id'] as int,
        name: json['name'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, if (name != null) 'name': name};
}

class TelegramMessageCountDto {
  final int messages;

  TelegramMessageCountDto({required this.messages});

  factory TelegramMessageCountDto.fromJson(Map<String, dynamic> json) =>
      TelegramMessageCountDto(messages: json['messages'] as int? ?? 0);

  Map<String, dynamic> toJson() => {'messages': messages};
}

// Response models

class TelegramBotsListResponse {
  final List<TelegramBotDto> bots;

  TelegramBotsListResponse({required this.bots});

  factory TelegramBotsListResponse.fromJson(Map<String, dynamic> json) =>
      TelegramBotsListResponse(
        bots: (json['bots'] as List<dynamic>? ?? [])
            .map((e) => TelegramBotDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TelegramBotResponse {
  final TelegramBotDto bot;

  TelegramBotResponse({required this.bot});

  factory TelegramBotResponse.fromJson(Map<String, dynamic> json) =>
      TelegramBotResponse(
        bot: TelegramBotDto.fromJson(json['bot'] as Map<String, dynamic>),
      );
}

class TelegramChatsListResponse {
  final List<TelegramChatDto> chats;
  final int total;
  final int limit;
  final int offset;

  TelegramChatsListResponse({
    required this.chats,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory TelegramChatsListResponse.fromJson(Map<String, dynamic> json) =>
      TelegramChatsListResponse(
        chats: (json['chats'] as List<dynamic>? ?? [])
            .map((e) => TelegramChatDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int? ?? 0,
        limit: json['limit'] as int? ?? 50,
        offset: json['offset'] as int? ?? 0,
      );
}

class TelegramMessageResponse {
  final bool success;
  final int? messageId;
  final DateTime? timestamp;

  TelegramMessageResponse({
    required this.success,
    this.messageId,
    this.timestamp,
  });

  factory TelegramMessageResponse.fromJson(Map<String, dynamic> json) =>
      TelegramMessageResponse(
        success: json['success'] as bool? ?? false,
        messageId: json['messageId'] as int?,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String)
            : null,
      );
}
