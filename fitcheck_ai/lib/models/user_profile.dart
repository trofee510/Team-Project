class UserProfile {
  final String id;
  final String userId;
  final List<String> aesthetics;
  final String? bodyType;
  final List<String> colorPreferences;
  final String? gender;
  final bool onboardingComplete;
  final bool notificationsEnabled;
  final String? notificationTime;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.userId,
    this.aesthetics = const [],
    this.bodyType,
    this.colorPreferences = const [],
    this.gender,
    this.onboardingComplete = false,
    this.notificationsEnabled = false,
    this.notificationTime,
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      aesthetics: (json['aesthetics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      bodyType: json['body_type'] as String?,
      colorPreferences: (json['color_preferences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      gender: json['gender'] as String?,
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? false,
      notificationTime: json['notification_time'] as String?,
      location: json['location'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'aesthetics': aesthetics,
        'body_type': bodyType,
        'color_preferences': colorPreferences,
        'gender': gender,
        'onboarding_complete': onboardingComplete,
        'notifications_enabled': notificationsEnabled,
        'notification_time': notificationTime,
        'location': location,
      };

  UserProfile copyWith({
    List<String>? aesthetics,
    String? bodyType,
    List<String>? colorPreferences,
    String? gender,
    bool? onboardingComplete,
    bool? notificationsEnabled,
    String? notificationTime,
    String? location,
  }) {
    return UserProfile(
      id: id,
      userId: userId,
      aesthetics: aesthetics ?? this.aesthetics,
      bodyType: bodyType ?? this.bodyType,
      colorPreferences: colorPreferences ?? this.colorPreferences,
      gender: gender ?? this.gender,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationTime: notificationTime ?? this.notificationTime,
      location: location ?? this.location,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
