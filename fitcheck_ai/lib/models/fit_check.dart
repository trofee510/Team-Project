class FitCheck {
  final String id;
  final String userId;
  final String? outfitId;
  final int score;
  final String feedback;
  final int? colorHarmonyScore;
  final int? styleCohesionScore;
  final int? occasionScore;
  final int? fitScore;
  final List<String>? improvementTips;
  final String? imagePath;
  final DateTime createdAt;

  const FitCheck({
    required this.id,
    required this.userId,
    this.outfitId,
    required this.score,
    required this.feedback,
    this.colorHarmonyScore,
    this.styleCohesionScore,
    this.occasionScore,
    this.fitScore,
    this.improvementTips,
    this.imagePath,
    required this.createdAt,
  });

  factory FitCheck.fromJson(Map<String, dynamic> json) {
    return FitCheck(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      outfitId: json['outfit_id'] as String?,
      score: json['score'] as int,
      feedback: json['feedback'] as String,
      colorHarmonyScore: json['color_harmony_score'] as int?,
      styleCohesionScore: json['style_cohesion_score'] as int?,
      occasionScore: json['occasion_score'] as int?,
      fitScore: json['fit_score'] as int?,
      improvementTips: (json['improvement_tips'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      imagePath: json['image_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'outfit_id': outfitId,
        'score': score,
        'feedback': feedback,
        'color_harmony_score': colorHarmonyScore,
        'style_cohesion_score': styleCohesionScore,
        'occasion_score': occasionScore,
        'fit_score': fitScore,
        'improvement_tips': improvementTips,
        'image_path': imagePath,
      };
}
