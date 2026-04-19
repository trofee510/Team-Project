class FitBattle {
  final String id;
  final String code;
  final String userId;
  final String? ownerDisplayName;
  final String imagePath;
  final String? caption;
  final int? aiScore;
  final String? aiFeedback;
  final DateTime expiresAt;
  final DateTime createdAt;

  const FitBattle({
    required this.id,
    required this.code,
    required this.userId,
    this.ownerDisplayName,
    required this.imagePath,
    this.caption,
    this.aiScore,
    this.aiFeedback,
    required this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory FitBattle.fromJson(Map<String, dynamic> json) {
    return FitBattle(
      id: json['id'] as String,
      code: json['code'] as String,
      userId: json['user_id'] as String,
      ownerDisplayName: json['owner_display_name'] as String?,
      imagePath: json['image_path'] as String,
      caption: json['caption'] as String?,
      aiScore: (json['ai_score'] as num?)?.toInt(),
      aiFeedback: json['ai_feedback'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class BattleRating {
  final String id;
  final String battleId;
  final String? raterId;
  final String raterName;
  final int score;
  final String? comment;
  final DateTime createdAt;

  const BattleRating({
    required this.id,
    required this.battleId,
    this.raterId,
    required this.raterName,
    required this.score,
    this.comment,
    required this.createdAt,
  });

  factory BattleRating.fromJson(Map<String, dynamic> json) {
    return BattleRating(
      id: json['id'] as String,
      battleId: json['battle_id'] as String,
      raterId: json['rater_id'] as String?,
      raterName: (json['rater_name'] as String?) ?? 'Friend',
      score: (json['score'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class BattleSummary {
  final FitBattle battle;
  final List<BattleRating> ratings;

  const BattleSummary({required this.battle, required this.ratings});

  double? get averageScore {
    if (ratings.isEmpty) return null;
    final sum = ratings.fold<int>(0, (a, r) => a + r.score);
    return sum / ratings.length;
  }

  int get ratingCount => ratings.length;
}
