import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/subscription_state.dart';

final usageTrackerProvider =
    StateNotifierProvider<UsageTracker, SubscriptionState>((ref) {
  return UsageTracker();
});

/// Tracks daily usage limits for free tier.
/// In production, this would sync with Supabase.
/// For now, it tracks in-memory and resets daily.
class UsageTracker extends StateNotifier<SubscriptionState> {
  UsageTracker() : super(const SubscriptionState());

  DateTime _lastResetDate = DateTime.now();

  void _resetIfNewDay() {
    final now = DateTime.now();
    if (now.day != _lastResetDate.day ||
        now.month != _lastResetDate.month ||
        now.year != _lastResetDate.year) {
      state = state.copyWith(
        dailyOutfitGenerations: 0,
        dailyFitChecks: 0,
      );
      _lastResetDate = now;
    }
  }

  void setProStatus(bool isPro) {
    state = state.copyWith(isPro: isPro);
  }

  void setWardrobeCount(int count) {
    state = state.copyWith(wardrobeItemCount: count);
  }

  bool canAddItem() {
    return state.canAddItem;
  }

  bool canGenerateOutfit() {
    _resetIfNewDay();
    return state.canGenerateOutfit;
  }

  bool canDoFitCheck() {
    _resetIfNewDay();
    return state.canDoFitCheck;
  }

  void recordOutfitGeneration() {
    _resetIfNewDay();
    state = state.copyWith(
      dailyOutfitGenerations: state.dailyOutfitGenerations + 1,
    );
  }

  void recordFitCheck() {
    _resetIfNewDay();
    state = state.copyWith(
      dailyFitChecks: state.dailyFitChecks + 1,
    );
  }

  void recordItemAdded() {
    state = state.copyWith(
      wardrobeItemCount: state.wardrobeItemCount + 1,
    );
  }

  String get remainingOutfitsText {
    if (state.isPro) return 'Unlimited';
    final remaining = AppConstants.freeDailyOutfits - state.dailyOutfitGenerations;
    return '$remaining left today';
  }

  String get remainingFitChecksText {
    if (state.isPro) return 'Unlimited';
    final remaining = AppConstants.freeDailyFitChecks - state.dailyFitChecks;
    return '$remaining left today';
  }

  String get remainingItemsText {
    if (state.isPro) return 'Unlimited';
    final remaining = AppConstants.freeWardrobeLimit - state.wardrobeItemCount;
    return '$remaining slots left';
  }
}
