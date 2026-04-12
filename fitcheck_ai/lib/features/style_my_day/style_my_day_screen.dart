import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/category.dart';
import '../../models/wardrobe_item.dart';
import '../wardrobe/wardrobe_controller.dart';

class StyleMyDayScreen extends ConsumerStatefulWidget {
  const StyleMyDayScreen({super.key});

  @override
  ConsumerState<StyleMyDayScreen> createState() => _StyleMyDayScreenState();
}

class _StyleMyDayScreenState extends ConsumerState<StyleMyDayScreen> {
  late PageController _topsCtrl;
  late PageController _bottomsCtrl;
  late PageController _shoesCtrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _topsCtrl = PageController(viewportFraction: 0.8);
    _bottomsCtrl = PageController(viewportFraction: 0.8);
    _shoesCtrl = PageController(viewportFraction: 0.8);
  }

  @override
  void dispose() {
    _topsCtrl.dispose();
    _bottomsCtrl.dispose();
    _shoesCtrl.dispose();
    super.dispose();
  }

  List<WardrobeItem> _filterByCategory(
      List<WardrobeItem> items, ClothingCategory cat) {
    return items.where((i) => i.category == cat).toList();
  }

  void _saveLook() {
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Look saved!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wardrobeAsync = ref.watch(wardrobeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Style My Day'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: wardrobeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          final tops = _filterByCategory(items, ClothingCategory.tops);
          final bottoms = _filterByCategory(items, ClothingCategory.bottoms);
          final shoes = _filterByCategory(items, ClothingCategory.shoes);

          if (tops.isEmpty && bottoms.isEmpty && shoes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.checkroom,
                        size: 64, color: AppTheme.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      'Add some clothes first!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Head to your Wardrobe tab and add\ntops, bottoms, and shoes to mix & match.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              const SizedBox(height: 8),
              Text(
                'Swipe to mix & match',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // ── Tops row ──
              _SlotSection(
                label: 'TOP',
                icon: Icons.checkroom,
                items: tops,
                controller: _topsCtrl,
              ),

              const SizedBox(height: 8),

              // ── Bottoms row ──
              _SlotSection(
                label: 'BOTTOM',
                icon: Icons.straighten,
                items: bottoms,
                controller: _bottomsCtrl,
              ),

              const SizedBox(height: 8),

              // ── Shoes row ──
              _SlotSection(
                label: 'SHOES',
                icon: Icons.ice_skating,
                items: shoes,
                controller: _shoesCtrl,
              ),

              const Spacer(),

              // ── Save button ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _saved ? null : _saveLook,
                    icon: Icon(_saved ? Icons.check : Icons.bookmark_rounded),
                    label: Text(_saved ? 'Saved!' : 'Save This Look'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _saved ? const Color(0xFF00C853) : AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

// ── Slot Section (label + swipeable cards) ──

class _SlotSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<WardrobeItem> items;
  final PageController controller;

  const _SlotSection({
    required this.label,
    required this.icon,
    required this.items,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        height: 130,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Center(
          child: Text(
            'No ${label.toLowerCase()}s yet',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length} items',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: controller,
            itemCount: items.length,
            itemBuilder: (ctx, i) => _ItemCard(item: items[i]),
          ),
        ),
      ],
    );
  }
}

// ── Individual swipeable card ──

class _ItemCard extends StatelessWidget {
  final WardrobeItem item;
  const _ItemCard({required this.item});

  Color _parseColor(String? colorName) {
    if (colorName == null) return AppTheme.primary;
    final lc = colorName.toLowerCase();
    const map = {
      'white': Color(0xFFF5F5F5),
      'black': Color(0xFF2D3436),
      'dark blue': Color(0xFF1A237E),
      'light blue': Color(0xFF90CAF9),
      'blue': Color(0xFF42A5F5),
      'khaki': Color(0xFFC8B560),
      'tan': Color(0xFFD2B48C),
      'brown': Color(0xFF795548),
      'red': Color(0xFFE53935),
      'green': Color(0xFF43A047),
      'grey': Color(0xFF9E9E9E),
      'gray': Color(0xFF9E9E9E),
      'silver': Color(0xFFBDBDBD),
      'navy': Color(0xFF1A237E),
      'beige': Color(0xFFF5F5DC),
      'pink': Color(0xFFEC407A),
    };
    return map[lc] ?? AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final bg = _parseColor(item.color);
    final isLight = bg.computeLuminance() > 0.5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Center icon
          Center(
            child: Icon(
              item.category.icon,
              size: 40,
              color: isLight
                  ? Colors.black.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          // Bottom label
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? 'Unnamed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isLight ? Colors.black87 : Colors.white,
                  ),
                ),
                if (item.subcategory != null)
                  Text(
                    item.subcategory!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isLight
                          ? Colors.black54
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          // Color dot
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isLight ? Colors.black12 : Colors.white24,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLight ? Colors.black26 : Colors.white38,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  item.color?.substring(0, 1).toUpperCase() ?? '?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isLight ? Colors.black54 : Colors.white70,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
