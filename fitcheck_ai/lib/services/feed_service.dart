import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_service.dart';

final feedServiceProvider = Provider<FeedService>((ref) {
  return FeedService(ref.watch(supabaseServiceProvider));
});

class FeedItem {
  final String fitCheckId;
  final String imagePath;
  final int aiScore;
  final String? challengeId;
  final String? challengeTitle;
  final DateTime createdAt;

  const FeedItem({
    required this.fitCheckId,
    required this.imagePath,
    required this.aiScore,
    required this.createdAt,
    this.challengeId,
    this.challengeTitle,
  });

  factory FeedItem.fromRow(Map<String, dynamic> row) {
    final challenge = row['challenges'];
    return FeedItem(
      fitCheckId: row['id'] as String,
      imagePath: row['image_path'] as String,
      aiScore: (row['score'] as num).toInt(),
      createdAt: DateTime.parse(row['created_at'] as String),
      challengeId: row['challenge_id'] as String?,
      challengeTitle: challenge is Map<String, dynamic>
          ? challenge['title'] as String?
          : null,
    );
  }
}

class LeaderboardEntry {
  final String fitCheckId;
  final String imagePath;
  final int aiScore;
  final double avgRating;
  final int ratingCount;

  const LeaderboardEntry({
    required this.fitCheckId,
    required this.imagePath,
    required this.aiScore,
    required this.avgRating,
    required this.ratingCount,
  });

  factory LeaderboardEntry.fromRow(Map<String, dynamic> row) {
    return LeaderboardEntry(
      fitCheckId: row['fit_check_id'] as String,
      imagePath: row['image_path'] as String,
      aiScore: (row['ai_score'] as num).toInt(),
      avgRating: (row['avg_rating'] as num).toDouble(),
      ratingCount: (row['rating_count'] as num).toInt(),
    );
  }
}

class Challenge {
  final String id;
  final String title;
  final String? description;
  final String? theme;
  final DateTime startDate;
  final DateTime endDate;

  const Challenge({
    required this.id,
    required this.title,
    this.description,
    this.theme,
    required this.startDate,
    required this.endDate,
  });

  factory Challenge.fromJson(Map<String, dynamic> j) {
    return Challenge(
      id: j['id'] as String,
      title: j['title'] as String,
      description: j['description'] as String?,
      theme: j['theme'] as String?,
      startDate: DateTime.parse(j['start_date'] as String),
      endDate: DateTime.parse(j['end_date'] as String),
    );
  }

  bool get isActive {
    final now = DateTime.now();
    return !now.isBefore(startDate) && !now.isAfter(endDate);
  }
}

class FeedService {
  final SupabaseService _supabase;

  FeedService(this._supabase);

  /// Queue of public fits this user hasn't rated yet. Newest first.
  /// Excludes the user's own fits and anything already rated.
  Future<List<FeedItem>> fetchQueue({int limit = 30}) async {
    final me = _supabase.userId;

    final rated = await _supabase.client
        .from('public_outfit_ratings')
        .select('fit_check_id')
        .eq('rater_id', me);
    final ratedIds =
        rated.map((r) => r['fit_check_id'] as String).toSet();

    var query = _supabase.client
        .from('fit_checks')
        .select('id, image_path, score, created_at, challenge_id, '
            'challenges(title)')
        .eq('is_public', true)
        .neq('user_id', me);

    if (ratedIds.isNotEmpty) {
      query = query.not('id', 'in', '(${ratedIds.join(',')})');
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => FeedItem.fromRow(r)).toList();
  }

  Future<void> rate(String fitCheckId, int score) async {
    await _supabase.client.from('public_outfit_ratings').upsert({
      'fit_check_id': fitCheckId,
      'rater_id': _supabase.userId,
      'score': score.clamp(1, 100),
    }, onConflict: 'fit_check_id,rater_id');
  }

  /// Top fits by community rating, last 7 days. Relies on a view
  /// `public_leaderboard_7d` (see supabase_schema.sql).
  Future<List<LeaderboardEntry>> leaderboard({int limit = 25}) async {
    final rows = await _supabase.client
        .from('public_leaderboard_7d')
        .select()
        .order('avg_rating', ascending: false)
        .limit(limit);
    return rows.map((r) => LeaderboardEntry.fromRow(r)).toList();
  }

  Future<List<Challenge>> activeChallenges() async {
    final now = DateTime.now().toIso8601String();
    final rows = await _supabase.client
        .from('challenges')
        .select()
        .lte('start_date', now)
        .gte('end_date', now)
        .order('end_date', ascending: true);
    return rows.map((r) => Challenge.fromJson(r)).toList();
  }

  /// Toggle public visibility on a past fit check.
  Future<void> setPublic(String fitCheckId, bool isPublic,
      {String? challengeId}) async {
    await _supabase.client
        .from('fit_checks')
        .update({
          'is_public': isPublic,
          if (challengeId != null) 'challenge_id': challengeId,
        })
        .eq('id', fitCheckId)
        .eq('user_id', _supabase.userId);
  }
}
