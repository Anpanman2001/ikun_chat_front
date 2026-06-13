class UserModel {
  final String id;
  final String username;
  final String nickname;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.username,
    required this.nickname,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? json['username'] ?? '',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'nickname': nickname,
        'avatar_url': avatarUrl,
      };
}
