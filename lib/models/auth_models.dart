class LoginRequest {
  final String email;
  final String password;
  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class UserDto {
  final int id;
  final String email;
  final String? name;
  final String role;
  final int? organizationId;

  UserDto({
    required this.id,
    required this.email,
    this.name,
    required this.role,
    this.organizationId,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
    id: json['id'] as int,
    email: json['email'] as String,
    name: json['name'] as String?,
    role: (json['role'] ?? 'user') as String,
    organizationId: json['organizationId'] as int?,
  );
}

class LoginResponse {
  final String token;
  final UserDto user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    token: json['token'] as String,
    user: UserDto.fromJson(json['user'] as Map<String, dynamic>),
  );
}
