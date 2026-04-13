import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final streakServiceProvider =
    StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  return StreakNotifier();
});

class StreakState {
  final int currentStreak;
  final int longestStreak;
  final int totalScored;
  final double avgScore;
  final bool scoredToday;
  final int dailyTarget; // score to beat

  const StreakState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalScored = 0,
    this.avgScore = 0,
    this.scoredToday = false,
    this.dailyTarget = 75,
  });

  StreakState copyWith({
    int? currentStreak,
    int? longestStreak,
    int? totalScored,
    double? avgScore,
    bool? scoredToday,
    int? dailyTarget,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalScored: totalScored ?? this.totalScored,
      avgScore: avgScore ?? this.avgScore,
      scoredToday: scoredToday ?? this.scoredToday,
      dailyTarget: dailyTarget ?? this.dailyTarget,
    );
  }
}

class StreakNotifier extends StateNotifier<StreakState> {
  StreakNotifier() : super(const StreakState()) {
    _load();
  }

  static const _keyStreak = 'streak_current';
  static const _keyLongest = 'streak_longest';
  static const _keyTotal = 'streak_total';
  static const _keyAvg = 'streak_avg';
  static const _keyLastDate = 'streak_last_date';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt(_keyStreak) ?? 0;
    final longest = prefs.getInt(_keyLongest) ?? 0;
    final total = prefs.getInt(_keyTotal) ?? 0;
    final avg = prefs.getDouble(_keyAvg) ?? 0;
    final lastDate = prefs.getString(_keyLastDate) ?? '';

    final today = _todayStr();
    final scoredToday = lastDate == today;

    // Check if streak is broken (missed yesterday)
    int currentStreak = streak;
    if (lastDate.isNotEmpty && !scoredToday) {
      final last = DateTime.tryParse(lastDate);
      if (last != null) {
        final diff = DateTime.now().difference(last).inDays;
        if (diff > 1) currentStreak = 0; // streak broken
      }
    }

    state = StreakState(
      currentStreak: currentStreak,
      longestStreak: longest,
      totalScored: total,
      avgScore: avg,
      scoredToday: scoredToday,
    );
  }

  Future<void> recordScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final lastDate = prefs.getString(_keyLastDate) ?? '';

    int newStreak = state.currentStreak;
    if (lastDate != today) {
      // First score today — extend streak
      newStreak += 1;
    }

    final newTotal = state.totalScored + 1;
    final newAvg =
        ((state.avgScore * state.totalScored) + score) / newTotal;
    final newLongest =
        newStreak > state.longestStreak ? newStreak : state.longestStreak;

    await prefs.setInt(_keyStreak, newStreak);
    await prefs.setInt(_keyLongest, newLongest);
    await prefs.setInt(_keyTotal, newTotal);
    await prefs.setDouble(_keyAvg, newAvg);
    await prefs.setString(_keyLastDate, today);

    state = state.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongest,
      totalScored: newTotal,
      avgScore: newAvg,
      scoredToday: true,
    );
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
