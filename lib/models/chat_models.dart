class OrganizationPhoneDto {
  final int id;
  final String phoneJid;
  final String? displayName;

  OrganizationPhoneDto({
    required this.id,
    required this.phoneJid,
    this.displayName,
  });

  factory OrganizationPhoneDto.fromJson(Map<String, dynamic> json) =>
      OrganizationPhoneDto(
        id: json['id'] as int,
        phoneJid: json['phoneJid'] as String,
        displayName: json['displayName'] as String?,
      );
}

class TelegramBotInfoDto {
  final int id;
  final String? botUsername;
  final String? botName;

  TelegramBotInfoDto({required this.id, this.botUsername, this.botName});

  factory TelegramBotInfoDto.fromJson(Map<String, dynamic> json) =>
      TelegramBotInfoDto(
        id: json['id'] as int,
        botUsername: json['botUsername'] as String?,
        botName: json['botName'] as String?,
      );
}

class AssignedUserDto {
  final int id;
  final String? name;
  final String? email;

  AssignedUserDto({required this.id, this.name, this.email});

  factory AssignedUserDto.fromJson(Map<String, dynamic> json) =>
      AssignedUserDto(
        id: json['id'] as int,
        name: json['name'] as String?,
        email: json['email'] as String?,
      );
}

class ChatDto {
  final int id;
  final String? name;
  final String channel; // 'whatsapp' | 'telegram'
  final String? remoteJid; // e.g. 7708...@s.whatsapp.net (для WhatsApp)
  final String? receivingPhoneJid;
  final int? organizationPhoneId;
  final OrganizationPhoneDto? organizationPhone;
  final bool? isGroup;
  final LastMessageDto? lastMessage;
  final String status; // open | pending | closed | new
  final String priority; // low | normal | high | urgent | medium
  final int unreadCount;
  final DateTime? lastMessageAt;
  final int? assignedUserId;
  final AssignedUserDto? assignedUser;
  final int? ticketNumber;
  final DateTime? createdAt;
  // Telegram-специфичные поля
  final TelegramBotInfoDto? telegramBot;
  final String? telegramChatId;
  final String? telegramUsername;
  final String? telegramFirstName;
  final String? telegramLastName;

  ChatDto({
    required this.id,
    this.name,
    required this.channel,
    this.remoteJid,
    this.receivingPhoneJid,
    this.organizationPhoneId,
    this.organizationPhone,
    required this.status,
    this.isGroup,
    this.lastMessage,
    required this.priority,
    required this.unreadCount,
    this.lastMessageAt,
    this.assignedUserId,
    this.assignedUser,
    this.ticketNumber,
    this.createdAt,
    this.telegramBot,
    this.telegramChatId,
    this.telegramUsername,
    this.telegramFirstName,
    this.telegramLastName,
  });

  factory ChatDto.fromJson(Map<String, dynamic> json) {
    final orgPhone = json['organizationPhone'] != null
        ? OrganizationPhoneDto.fromJson(
            json['organizationPhone'] as Map<String, dynamic>,
          )
        : null;

    return ChatDto(
      id: json['id'] as int,
      name: json['name'] as String?,
      channel: json['channel'] as String? ?? 'whatsapp',
      remoteJid: json['remoteJid'] as String?,
      receivingPhoneJid: json['receivingPhoneJid'] as String?,
      // Если есть объект organizationPhone, берем ID из него, иначе из поля organizationPhoneId
      organizationPhoneId: orgPhone?.id ?? json['organizationPhoneId'] as int?,
      organizationPhone: orgPhone,
      isGroup: json['isGroup'] as bool?,
      lastMessage: json['lastMessage'] != null
          ? LastMessageDto.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String,
      priority: json['priority'] as String? ?? 'normal',
      unreadCount: json['unreadCount'] as int? ?? 0,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'] as String)
          : null,
      assignedUserId: json['assignedUserId'] as int?,
      assignedUser: json['assignedUser'] != null
          ? AssignedUserDto.fromJson(
              json['assignedUser'] as Map<String, dynamic>,
            )
          : null,
      ticketNumber: json['ticketNumber'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      telegramBot: json['telegramBot'] != null
          ? TelegramBotInfoDto.fromJson(
              json['telegramBot'] as Map<String, dynamic>,
            )
          : null,
      telegramChatId: json['telegramChatId'] as String?,
      telegramUsername: json['telegramUsername'] as String?,
      telegramFirstName: json['telegramFirstName'] as String?,
      telegramLastName: json['telegramLastName'] as String?,
    );
  }

  // Вспомогательные геттеры
  bool get isTelegram => channel == 'telegram';
  bool get isWhatsApp => channel == 'whatsapp';

  String get displayName {
    if (isTelegram) {
      if (telegramFirstName != null || telegramLastName != null) {
        return '${telegramFirstName ?? ''} ${telegramLastName ?? ''}'.trim();
      }
      if (telegramUsername != null) return '@$telegramUsername';
      if (name != null) return name!;
      return 'Telegram чат #$id';
    }
    // WhatsApp
    return name ?? remoteJid ?? 'Чат #$id';
  }
}

class LastMessageDto {
  final int id;
  final String? content;
  final String? senderJid;
  final DateTime? timestamp;
  final bool? fromMe;
  final String? type;
  final bool? isReadByOperator;
  final String? mediaUrl;

  LastMessageDto({
    required this.id,
    this.content,
    this.senderJid,
    this.timestamp,
    this.fromMe,
    this.type,
    this.isReadByOperator,
    this.mediaUrl,
  });

  factory LastMessageDto.fromJson(Map<String, dynamic> json) => LastMessageDto(
    id: json['id'] as int,
    content: json['content'] as String?,
    senderJid: json['senderJid'] as String?,
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String)
        : null,
    fromMe: json['fromMe'] as bool?,
    type: json['type'] as String?,
    isReadByOperator: json['isReadByOperator'] as bool?,
    mediaUrl: json['mediaUrl'] as String?,
  );
}

class MessageDto {
  final int id;
  final int? chatId; // сделаем опциональным
  final String type; // text | image | video | document | audio
  final String content; // text or caption
  final String? mediaUrl;
  final String? senderJid;
  final int? senderUserId; // null = входящее (клиент)
  final DateTime timestamp;
  final bool isRead;
  final bool fromMe; // true если от оператора
  final SenderUserDto? senderUser; // информация об операторе

  MessageDto({
    required this.id,
    this.chatId, // теперь опциональный
    required this.type,
    required this.content,
    this.mediaUrl,
    this.senderJid,
    this.senderUserId,
    required this.timestamp,
    required this.isRead,
    required this.fromMe,
    this.senderUser,
  });

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    final senderUser = json['senderUser'] != null
        ? SenderUserDto.fromJson(json['senderUser'] as Map<String, dynamic>)
        : null;

    return MessageDto(
      id: json['id'] as int,
      chatId: json['chatId'] as int?,
      type: json['type'] as String? ?? json['messageType'] as String? ?? 'text',
      content:
          (json['text'] ?? json['content'] ?? json['caption'] ?? '') as String,
      mediaUrl: json['mediaUrl'] as String?,
      senderJid: json['senderJid'] as String?,
      senderUserId: json['senderUserId'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead:
          json['isRead'] as bool? ?? json['isReadByOperator'] as bool? ?? false,
      // Сообщение от оператора если есть senderUser
      fromMe: json['fromMe'] as bool? ?? (senderUser != null),
      senderUser: senderUser,
    );
  }
}

class SenderUserDto {
  final int id;
  final String? name;
  final String? email;

  SenderUserDto({required this.id, this.name, this.email});

  factory SenderUserDto.fromJson(Map<String, dynamic> json) => SenderUserDto(
    id: json['id'] as int,
    name: json['name'] as String?,
    email: json['email'] as String?,
  );
}

class ChatsListResponse {
  final List<ChatDto> chats;
  final int total;

  ChatsListResponse({required this.chats, required this.total});

  factory ChatsListResponse.fromJson(Map<String, dynamic> json) =>
      ChatsListResponse(
        chats: (json['chats'] as List<dynamic>? ?? [])
            .map((e) => ChatDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int? ?? 0,
      );
}

class MessagesResponse {
  final List<MessageDto> messages;
  MessagesResponse({required this.messages});
  factory MessagesResponse.fromJson(Map<String, dynamic> json) =>
      MessagesResponse(
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((e) => MessageDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// Модель для параметров фильтрации чатов
class ChatFilters {
  final String? status; // open | pending | closed
  final bool?
  assigned; // true - только назначенные, false - неназначенные, null - все
  final String? priority; // low | normal | high | urgent
  final bool? includeProfile; // добавлять displayName из Chat.name
  final bool? assignedToMe; // true - чаты назначенные текущему пользователю

  ChatFilters({
    this.status,
    this.assigned,
    this.priority,
    this.includeProfile,
    this.assignedToMe,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (assigned != null) params['assigned'] = assigned.toString();
    if (priority != null) params['priority'] = priority;
    if (includeProfile != null)
      params['includeProfile'] = includeProfile.toString();
    if (assignedToMe != null) params['assignedToMe'] = assignedToMe.toString();
    return params;
  }

  // Для сохранения в SharedPreferences
  Map<String, dynamic> toJson() => {
    'status': status,
    'assigned': assigned,
    'priority': priority,
    'includeProfile': includeProfile,
    'assignedToMe': assignedToMe,
  };

  factory ChatFilters.fromJson(Map<String, dynamic> json) => ChatFilters(
    status: json['status'] as String?,
    assigned: json['assigned'] as bool?,
    priority: json['priority'] as String?,
    includeProfile: json['includeProfile'] as bool?,
    assignedToMe: json['assignedToMe'] as bool?,
  );
}

// Модель для ответа профиля чата
class ChatProfileResponse {
  final String jid;
  final String? photoUrl;

  ChatProfileResponse({required this.jid, this.photoUrl});

  factory ChatProfileResponse.fromJson(Map<String, dynamic> json) =>
      ChatProfileResponse(
        jid: json['jid'] as String,
        photoUrl: json['photoUrl'] as String?,
      );
}
