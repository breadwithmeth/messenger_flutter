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

class ClientDto {
  final String phoneJid;
  final String? name;

  ClientDto({required this.phoneJid, this.name});

  factory ClientDto.fromJson(Map<String, dynamic> json) => ClientDto(
    phoneJid: json['phoneJid'] as String,
    name: json['name'] as String?,
  );
}

class LastMessageDto {
  final int id;
  final String? content;
  final DateTime? timestamp;

  LastMessageDto({required this.id, this.content, this.timestamp});

  factory LastMessageDto.fromJson(Map<String, dynamic> json) => LastMessageDto(
    id: json['id'] as int,
    content: json['content'] as String?,
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String)
        : null,
  );
}

class TicketDto {
  final int id;
  final int ticketNumber;
  final String status; // new, open, in_progress, pending, resolved, closed
  final String priority; // low, normal, high, urgent
  final String? subject;
  final String? category;
  final List<String> tags;
  final AssignedUserDto? assignedUser;
  final ClientDto? client;
  final int unreadCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final LastMessageDto? lastMessage;
  final DateTime? assignedAt;
  final String? internalNotes;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final String? closeReason;
  final int? customerRating;
  // Новые поля из API
  final String? name;
  final String? remoteJid;
  final String? receivingPhoneJid;

  TicketDto({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.priority,
    this.subject,
    this.category,
    this.tags = const [],
    this.assignedUser,
    this.client,
    required this.unreadCount,
    this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.lastMessage,
    this.assignedAt,
    this.internalNotes,
    this.firstResponseAt,
    this.resolvedAt,
    this.closedAt,
    this.closeReason,
    this.customerRating,
    this.name,
    this.remoteJid,
    this.receivingPhoneJid,
  });

  // Удобные геттеры для получения информации о клиенте
  String? get clientName => name ?? client?.name;
  String? get clientPhone => remoteJid ?? client?.phoneJid;

  factory TicketDto.fromJson(Map<String, dynamic> json) => TicketDto(
    id: json['id'] as int,
    ticketNumber: json['ticketNumber'] as int,
    status: json['status'] as String,
    priority: json['priority'] as String? ?? 'normal',
    subject: json['subject'] as String?,
    category: json['category'] as String?,
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [],
    assignedUser: json['assignedUser'] != null
        ? AssignedUserDto.fromJson(json['assignedUser'] as Map<String, dynamic>)
        : null,
    client: json['client'] != null
        ? ClientDto.fromJson(json['client'] as Map<String, dynamic>)
        : null,
    unreadCount: json['unreadCount'] as int? ?? 0,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)
        : null,
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String)
        : null,
    lastMessageAt: json['lastMessageAt'] != null
        ? DateTime.tryParse(json['lastMessageAt'] as String)
        : null,
    lastMessage: json['lastMessage'] != null
        ? LastMessageDto.fromJson(json['lastMessage'] as Map<String, dynamic>)
        : null,
    assignedAt: json['assignedAt'] != null
        ? DateTime.tryParse(json['assignedAt'] as String)
        : null,
    internalNotes: json['internalNotes'] as String?,
    firstResponseAt: json['firstResponseAt'] != null
        ? DateTime.tryParse(json['firstResponseAt'] as String)
        : null,
    resolvedAt: json['resolvedAt'] != null
        ? DateTime.tryParse(json['resolvedAt'] as String)
        : null,
    closedAt: json['closedAt'] != null
        ? DateTime.tryParse(json['closedAt'] as String)
        : null,
    closeReason: json['closeReason'] as String?,
    customerRating: json['customerRating'] as int?,
    name: json['name'] as String?,
    remoteJid: json['remoteJid'] as String?,
    receivingPhoneJid: json['receivingPhoneJid'] as String?,
  );
}

class TicketListResponse {
  final List<TicketDto> tickets;
  final PaginationDto pagination;

  TicketListResponse({required this.tickets, required this.pagination});

  factory TicketListResponse.fromJson(Map<String, dynamic> json) =>
      TicketListResponse(
        tickets: (json['tickets'] as List<dynamic>)
            .map((e) => TicketDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: PaginationDto.fromJson(
          json['pagination'] as Map<String, dynamic>,
        ),
      );
}

class PaginationDto {
  final int total;
  final int page;
  final int limit;
  final int pages;

  PaginationDto({
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  factory PaginationDto.fromJson(Map<String, dynamic> json) => PaginationDto(
    total: json['total'] as int,
    page: json['page'] as int,
    limit: json['limit'] as int,
    pages: json['pages'] as int,
  );
}

class TicketHistoryDto {
  final int id;
  final String changeType;
  final String? oldValue;
  final String? newValue;
  final String description;
  final AssignedUserDto? user;
  final DateTime? createdAt;

  TicketHistoryDto({
    required this.id,
    required this.changeType,
    this.oldValue,
    this.newValue,
    required this.description,
    this.user,
    this.createdAt,
  });

  factory TicketHistoryDto.fromJson(Map<String, dynamic> json) =>
      TicketHistoryDto(
        id: json['id'] as int,
        changeType: json['changeType'] as String,
        oldValue: json['oldValue'] as String?,
        newValue: json['newValue'] as String?,
        description: json['description'] as String,
        user: json['user'] != null
            ? AssignedUserDto.fromJson(json['user'] as Map<String, dynamic>)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

class TicketStatsDto {
  final int total;
  final Map<String, int> byStatus;
  final Map<String, int> byPriority;

  TicketStatsDto({
    required this.total,
    required this.byStatus,
    required this.byPriority,
  });

  factory TicketStatsDto.fromJson(Map<String, dynamic> json) => TicketStatsDto(
    total: json['total'] as int,
    byStatus: (json['byStatus'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as int),
    ),
    byPriority: (json['byPriority'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as int),
    ),
  );
}
