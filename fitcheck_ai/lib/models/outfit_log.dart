class OutfitLog {
  final String id;
  final String userId;
  final String outfitId;
  final DateTime wornDate;
  final String? notes;
  final String? selfieImagePath;
  final DateTime createdAt;

  const OutfitLog({
    required this.id,
    required this.userId,
    required this.outfitId,
    required this.wornDate,
    this.notes,
    this.selfieImagePath,
    required this.createdAt,
  });

  factory OutfitLog.fromJson(Map<String, dynamic> json) {
    return OutfitLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      outfitId: json['outfit_id'] as String,
      wornDate: DateTime.parse(json['worn_date'] as String),
      notes: json['notes'] as String?,
      selfieImagePath: json['selfie_image_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'outfit_id': outfitId,
        'worn_date': wornDate.toIso8601String().split('T').first,
        'notes': notes,
        'selfie_image_path': selfieImagePath,
      };
}
