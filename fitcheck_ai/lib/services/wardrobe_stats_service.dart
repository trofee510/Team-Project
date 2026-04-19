import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wardrobe_item.dart';
import 'supabase_service.dart';

final wardrobeStatsServiceProvider = Provider<WardrobeStatsService>((ref) {
  return WardrobeStatsService(ref.watch(supabaseServiceProvider));
});

class CostPerWearEntry {
  final WardrobeItem item;
  final double costPerWear;
  final double totalSpent;
  final int wearCount;

  const CostPerWearEntry({
    required this.item,
    required this.costPerWear,
    required this.totalSpent,
    required this.wearCount,
  });
}

class DeadItem {
  final WardrobeItem item;
  final int daysOwned;

  const DeadItem({required this.item, required this.daysOwned});
}

class WardrobeStatsSummary {
  final List<CostPerWearEntry> bestValue;    // low $/wear
  final List<CostPerWearEntry> worstValue;   // high $/wear
  final List<DeadItem> deadItems;            // 0 wears in last 90 days
  final double totalClosetValue;
  final double avgCostPerWear;

  const WardrobeStatsSummary({
    required this.bestValue,
    required this.worstValue,
    required this.deadItems,
    required this.totalClosetValue,
    required this.avgCostPerWear,
  });
}

class WardrobeStatsService {
  final SupabaseService _supabase;

  WardrobeStatsService(this._supabase);

  /// Computes closet-wide stats from wardrobe_items + outfit_logs.
  ///
  /// Dead items = no appearance in outfit_logs in the last [deadWindowDays].
  /// We only compute $/wear when `purchase_price` is set and `wear_count > 0`.
  Future<WardrobeStatsSummary> compute({int deadWindowDays = 90}) async {
    final items = await _supabase.getWardrobeItems();

    // Grab recent outfit logs → map of wardrobe_item_id → most-recent wear.
    final cutoff = DateTime.now().subtract(Duration(days: deadWindowDays));
    final wornIds = await _recentlyWornIds(cutoff);

    final cpwEntries = <CostPerWearEntry>[];
    final dead = <DeadItem>[];
    double closetValue = 0;
    double cpwSum = 0;
    int cpwCount = 0;

    for (final item in items) {
      final price = item.purchasePrice ?? 0;
      closetValue += price;

      if (price > 0 && item.wearCount > 0) {
        final cpw = price / item.wearCount;
        cpwSum += cpw;
        cpwCount++;
        cpwEntries.add(CostPerWearEntry(
          item: item,
          costPerWear: cpw,
          totalSpent: price,
          wearCount: item.wearCount,
        ));
      }

      if (!wornIds.contains(item.id)) {
        final age = DateTime.now().difference(item.createdAt).inDays;
        // Only items owned long enough to count as "dead".
        if (age >= deadWindowDays ~/ 3) {
          dead.add(DeadItem(item: item, daysOwned: age));
        }
      }
    }

    cpwEntries.sort((a, b) => a.costPerWear.compareTo(b.costPerWear));
    final best = cpwEntries.take(5).toList();
    final worst = cpwEntries.reversed.take(5).toList();
    dead.sort((a, b) => b.daysOwned.compareTo(a.daysOwned));

    return WardrobeStatsSummary(
      bestValue: best,
      worstValue: worst,
      deadItems: dead.take(10).toList(),
      totalClosetValue: closetValue,
      avgCostPerWear: cpwCount == 0 ? 0 : cpwSum / cpwCount,
    );
  }

  Future<Set<String>> _recentlyWornIds(DateTime cutoff) async {
    // outfit_logs → outfits → outfit_items.wardrobe_item_id
    final logs = await _supabase.client
        .from('outfit_logs')
        .select('outfit_id')
        .eq('user_id', _supabase.userId)
        .gte('worn_date', cutoff.toIso8601String().split('T').first);
    final outfitIds =
        (logs as List).map((r) => r['outfit_id'] as String).toSet();
    if (outfitIds.isEmpty) return {};

    final joins = await _supabase.client
        .from('outfit_items')
        .select('wardrobe_item_id, outfit_id')
        .inFilter('outfit_id', outfitIds.toList());

    return (joins as List)
        .map((r) => r['wardrobe_item_id'] as String)
        .toSet();
  }
}
