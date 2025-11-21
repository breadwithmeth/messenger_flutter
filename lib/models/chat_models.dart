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
  final String? remoteJid; // e.g. 7708...@s.whatsapp.net
  final String? receivingPhoneJid;
  final int? organizationPhoneId;
  final OrganizationPhoneDto? organizationPhone;
  final bool? isGroup;
  final LastMessageDto? lastMessage;
  final String status; // open | pending | closed
  final String priority; // low | normal | high | urgent
  final int unreadCount;
  final DateTime? lastMessageAt;
  final int? assignedUserId;
  final AssignedUserDto? assignedUser;

  ChatDto({
    required this.id,
    this.name,
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
  });

  factory ChatDto.fromJson(Map<String, dynamic> json) => ChatDto(
    id: json['id'] as int,
    name: json['name'] as String?,
    remoteJid: json['remoteJid'] as String?,
    receivingPhoneJid: json['receivingPhoneJid'] as String?,
    organizationPhoneId: json['organizationPhoneId'] as int?,
    organizationPhone: json['organizationPhone'] != null
        ? OrganizationPhoneDto.fromJson(
            json['organizationPhone'] as Map<String, dynamic>,
          )
        : null,
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
        ? AssignedUserDto.fromJson(json['assignedUser'] as Map<String, dynamic>)
        : null,
  );
}

class LastMessageDto {
  final int id;
  final String? content;
  final String? senderJid;
  final DateTime? timestamp;
  final bool? fromMe;
  final String? type;
  final bool? isReadByOperator;

  LastMessageDto({
    required this.id,
    this.content,
    this.senderJid,
    this.timestamp,
    this.fromMe,
    this.type,
    this.isReadByOperator,
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
  );
}

class MessageDto {
  final int id;
  final int chatId;
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
    required this.chatId,
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

  factory MessageDto.fromJson(Map<String, dynamic> json) => MessageDto(
    id: json['id'] as int,
    chatId: json['chatId'] as int,
    type: json['type'] as String? ?? json['messageType'] as String? ?? 'text',
    content:
        (json['text'] ?? json['content'] ?? json['caption'] ?? '') as String,
    mediaUrl: json['mediaUrl'] as String?,
    senderJid: json['senderJid'] as String?,
    senderUserId: json['senderUserId'] as int?,
    timestamp: DateTime.parse(json['timestamp'] as String),
    isRead: json['isRead'] as bool? ?? false,
    fromMe: json['fromMe'] as bool? ?? (json['senderUserId'] != null),
    senderUser: json['senderUser'] != null
        ? SenderUserDto.fromJson(json['senderUser'] as Map<String, dynamic>)
        : null,
  );
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
