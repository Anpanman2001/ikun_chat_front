/// 游戏排行榜条目
class GameScore {
  final int rank;
  final String userId;
  final String nickname;
  final int score;

  GameScore({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.score,
  });

  factory GameScore.fromJson(Map<String, dynamic> json) {
    return GameScore(
      rank: json['rank'] ?? 0,
      userId: (json['user_id'] ?? '').toString(),
      nickname: json['nickname'] ?? '',
      score: json['score'] ?? 0,
    );
  }

  /// 第一名
  bool get isFirst => rank == 1;

  /// 第二名
  bool get isSecond => rank == 2;

  /// 第三名
  bool get isThird => rank == 3;

  /// 奖牌 emoji
  String get medalEmoji {
    if (isFirst) return '\ud83e\udd47';
    if (isSecond) return '\ud83e\udd48';
    if (isThird) return '\ud83e\udd49';
    return '$rank';
  }
}
