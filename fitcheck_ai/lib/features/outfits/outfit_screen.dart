import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../models/category.dart';
import '../../models/outfit.dart';
import '../../models/wardrobe_item.dart';
import '../../services/share_service.dart';
import '../../services/supabase_service.dart';

final outfitDetailProvider =
    FutureProvider.family<_OutfitDetail, String>((ref, outfitId) async {
  if (kDemoMode) {
    return _OutfitDetail(
      outfit: Outfit(
        id: outfitId, userId: 'demo', occasion: 'casual',
        reasoning: 'The white tee and slim jeans create a timeless casual look. White sneakers keep everything cohesive and clean.',
        createdAt: DateTime.now(),
      ),
      items: [
        _OutfitItemDetail(slot: 'top', wardrobeItem: WardrobeItem(
          id: '1', userId: 'demo', category: ClothingCategory.tops,
          color: 'White', imagePath: 'demo', name: 'White Tee', createdAt: DateTime.now(),
        )),
        _OutfitItemDetail(slot: 'bottom', wardrobeItem: WardrobeItem(
          id: '3', userId: 'demo', category: ClothingCategory.bottoms,
          color: 'Dark Blue', imagePath: 'demo', name: 'Slim Jeans', createdAt: DateTime.now(),
        )),
        _OutfitItemDetail(slot: 'shoes', wardrobeItem: WardrobeItem(
          id: '5', userId: 'demo', category: ClothingCategory.shoes,
          color: 'White', imagePath: 'demo', name: 'White Sneakers', createdAt: DateTime.now(),
        )),
      ],
    );
  }

  final supabase = ref.read(supabaseServiceProvider);
  final outfits = await supabase.getOutfits();
  final outfit = outfits.firstWhere((o) => o.id == outfitId);
  final outfitItems = await supabase.getOutfitItems(outfitId);
  final wardrobeItems = await supabase.getWardrobeItems();

  final itemsWithDetails = outfitItems.map((oi) {
    final wardrobeItem = wardrobeItems
        .where((wi) => wi.id == oi.wardrobeItemId)
        .firstOrNull;
    return _OutfitItemDetail(slot: oi.slot, wardrobeItem: wardrobeItem);
  }).toList();

  return _OutfitDetail(outfit: outfit, items: itemsWithDetails);
});

class OutfitScreen extends ConsumerWidget {
  final String outfitId;

  const OutfitScreen({super.key, required this.outfitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(outfitDetailProvider(outfitId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Outfit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final detail = ref.read(outfitDetailProvider(outfitId)).value;
              if (detail == null) return;
              final items = detail.items
                  .where((i) => i.wardrobeItem != null)
                  .map((i) => i.wardrobeItem!)
                  .toList();
              ref.read(shareServiceProvider).shareOutfitCard(
                    occasion: detail.outfit.occasion ?? 'outfit',
                    items: items,
                  );
            },
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (detail) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Occasion badge
              if (detail.outfit.occasion != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      detail.outfit.occasion!.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Outfit items grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: detail.items.length,
                itemBuilder: (context, index) {
                  final item = detail.items[index];
                  return _OutfitItemCard(item: item);
                },
              ),

              const SizedBox(height: 24),

              // Reasoning
              if (detail.outfit.reasoning != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          detail.outfit.reasoning!,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Fit Check button
              ElevatedButton.icon(
                onPressed: () => context.push('/fit-check/$outfitId'),
                icon: const Icon(Icons.star),
                label: const Text('Get Fit Check Score'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutfitItemCard extends StatelessWidget {
  final _OutfitItemDetail item;

  const _OutfitItemCard({required this.item});

  Color _colorFromName(String? colorName) {
    return switch (colorName?.toLowerCase()) {
      'white' => Colors.blueGrey.shade200,
      'black' => Colors.grey.shade800,
      'dark blue' || 'navy' => Colors.indigo.shade400,
      'light blue' => Colors.lightBlue.shade300,
      'khaki' || 'beige' => Colors.amber.shade300,
      'brown' => Colors.brown.shade400,
      'silver' || 'grey' || 'gray' => Colors.blueGrey.shade300,
      _ => AppTheme.primary.withValues(alpha: 0.6),
    };
  }

  @override
  Widget build(BuildContext context) {
    final wi = item.wardrobeItem;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                width: double.infinity,
                color: _colorFromName(wi?.color),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        wi?.category.icon ?? Icons.checkroom,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wi?.name ?? item.slot,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              item.slot.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutfitDetail {
  final Outfit outfit;
  final List<_OutfitItemDetail> items;

  _OutfitDetail({required this.outfit, required this.items});
}

class _OutfitItemDetail {
  final String slot;
  final WardrobeItem? wardrobeItem;

  _OutfitItemDetail({required this.slot, this.wardrobeItem});
}
