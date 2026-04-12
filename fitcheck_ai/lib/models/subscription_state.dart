class SubscriptionState {
  final bool isPro;
  final String? entitlementId;
  final DateTime? expirationDate;
  final int wardrobeItemCount;
  final int dailyOutfitGenerations;
  final int dailyFitChecks;

  const SubscriptionState({
    this.isPro = false,
    this.entitlementId,
    this.expirationDate,
    this.wardrobeItemCount = 0,
    this.dailyOutfitGenerations = 0,
    this.dailyFitChecks = 0,
  });

  bool get canAddItem => isPro || wardrobeItemCount < 20;
  bool get canGenerateOutfit => isPro || dailyOutfitGenerations < 3;
  bool get canDoFitCheck => isPro || dailyFitChecks < 3;

  SubscriptionState copyWith({
    bool? isPro,
    String? entitlementId,
    DateTime? expirationDate,
    int? wardrobeItemCount,
    int? dailyOutfitGenerations,
    int? dailyFitChecks,
  }) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
      entitlementId: entitlementId ?? this.entitlementId,
      expirationDate: expirationDate ?? this.expirationDate,
      wardrobeItemCount: wardrobeItemCount ?? this.wardrobeItemCount,
      dailyOutfitGenerations:
          dailyOutfitGenerations ?? this.dailyOutfitGenerations,
      dailyFitChecks: dailyFitChecks ?? this.dailyFitChecks,
    );
  }
}
