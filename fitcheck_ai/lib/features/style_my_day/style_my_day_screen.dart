import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../models/category.dart';
import '../../models/wardrobe_item.dart';
import '../wardrobe/wardrobe_controller.dart';

class StyleMyDayScreen extends ConsumerStatefulWidget {
  const StyleMyDayScreen({super.key});

  @override
  ConsumerState<StyleMyDayScreen> createState() => _StyleMyDayScreenState();
}

class _StyleMyDayScreenState extends ConsumerState<StyleMyDayScreen> {
  int _topIdx = 0;
  int _bottomIdx = 0;
  int _shoeIdx = 0;
  bool _saved = false;

  List<WardrobeItem> _filter(List<WardrobeItem> items, ClothingCategory cat) =>
      items.where((i) => i.category == cat).toList();

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
      backgroundColor: const Color(0xFF0b0d10),
      appBar: AppBar(
        title: const Text('Style My Day'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: wardrobeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e',
            style: const TextStyle(color: Colors.white70))),
        data: (items) {
          final tops = _filter(items, ClothingCategory.tops);
          final bottoms = _filter(items, ClothingCategory.bottoms);
          final shoes = _filter(items, ClothingCategory.shoes);

          if (tops.isEmpty && bottoms.isEmpty && shoes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.checkroom, size: 64, color: Colors.white38),
                    const SizedBox(height: 16),
                    const Text('Add some clothes first!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                    const SizedBox(height: 8),
                    const Text(
                      'Head to your Wardrobe tab and add\ntops, bottoms, and shoes to mix & match.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              const SizedBox(height: 4),
              Text('Swipe each zone to mix & match',
                  style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(height: 8),

              // ── Mannequin body with overlaid clothing ──
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 280,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // Body silhouette behind everything
                        Positioned.fill(
                          child: CustomPaint(painter: _BodySilhouettePainter()),
                        ),

                        // TOP zone — upper 38% of body
                        Positioned(
                          top: 40,
                          left: 30,
                          right: 30,
                          height: 200,
                          child: _SwipeZone(
                            items: tops,
                            index: _topIdx,
                            label: 'TOP',
                            emptyLabel: 'No tops',
                            alignment: Alignment.bottomCenter,
                            onChanged: (i) => setState(() => _topIdx = i),
                          ),
                        ),

                        // BOTTOM zone — middle 35% of body
                        Positioned(
                          top: 240,
                          left: 35,
                          right: 35,
                          height: 220,
                          child: _SwipeZone(
                            items: bottoms,
                            index: _bottomIdx,
                            label: 'BOTTOM',
                            emptyLabel: 'No bottoms',
                            alignment: Alignment.topCenter,
                            onChanged: (i) => setState(() => _bottomIdx = i),
                          ),
                        ),

                        // SHOES zone — bottom 20%
                        Positioned(
                          bottom: 10,
                          left: 55,
                          right: 55,
                          height: 100,
                          child: _SwipeZone(
                            items: shoes,
                            index: _shoeIdx,
                            label: 'SHOES',
                            emptyLabel: 'No shoes',
                            alignment: Alignment.center,
                            onChanged: (i) => setState(() => _shoeIdx = i),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Item labels ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ItemLabel(items: tops, index: _topIdx, slot: 'Top'),
                    _ItemLabel(items: bottoms, index: _bottomIdx, slot: 'Bottom'),
                    _ItemLabel(items: shoes, index: _shoeIdx, slot: 'Shoes'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Save button ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _saved ? null : _saveLook,
                    icon: Icon(_saved ? Icons.check : Icons.bookmark_rounded),
                    label: Text(_saved ? 'Saved!' : 'Save This Look'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _saved
                          ? const Color(0xFF00C853) : AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

// ── Swipeable zone overlaid on the mannequin ──

class _SwipeZone extends StatelessWidget {
  final List<WardrobeItem> items;
  final int index;
  final String label;
  final String emptyLabel;
  final Alignment alignment;
  final ValueChanged<int> onChanged;

  const _SwipeZone({
    required this.items,
    required this.index,
    required this.label,
    required this.emptyLabel,
    required this.alignment,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(emptyLabel,
              style: const TextStyle(color: Colors.white24, fontSize: 12)),
        ),
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -100) {
          // swipe left → next
          onChanged((index + 1) % items.length);
        } else if (details.primaryVelocity! > 100) {
          // swipe right → prev
          onChanged((index - 1 + items.length) % items.length);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: ClipRRect(
          key: ValueKey('${label}_$index'),
          borderRadius: BorderRadius.circular(4),
          child: _ClothingImage(
            item: items[index],
            alignment: alignment,
          ),
        ),
      ),
    );
  }
}

// ── Loads the clothing image from Supabase or shows fallback ──

class _ClothingImage extends StatelessWidget {
  final WardrobeItem item;
  final Alignment alignment;

  const _ClothingImage({required this.item, required this.alignment});

  String? _imageUrl() {
    if (kDemoMode || item.imagePath == 'demo') return null;
    final path = item.thumbnailPath ?? item.imagePath;
    return Supabase.instance.client.storage
        .from(AppConstants.wardrobeBucket)
        .getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl();
    if (url == null) return _fallback();

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: alignment,
      placeholder: (_, __) => Container(
        color: Colors.white10,
        child: const Center(
          child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30)),
        ),
      ),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _colorFromName(item.color),
      child: Center(
        child: Icon(item.category.icon, size: 32,
            color: Colors.white.withValues(alpha: 0.4)),
      ),
    );
  }

  Color _colorFromName(String? c) {
    return switch (c?.toLowerCase()) {
      'white' => const Color(0xFFE0E0E0),
      'black' => const Color(0xFF2D3436),
      'dark blue' || 'navy' => const Color(0xFF1A237E),
      'light blue' => const Color(0xFF90CAF9),
      'blue' => const Color(0xFF42A5F5),
      'khaki' || 'beige' || 'tan' => const Color(0xFFC8B560),
      'brown' => const Color(0xFF795548),
      'red' => const Color(0xFFE53935),
      'green' => const Color(0xFF43A047),
      'grey' || 'gray' || 'silver' => const Color(0xFF9E9E9E),
      'pink' => const Color(0xFFEC407A),
      _ => AppTheme.primary,
    };
  }
}

// ── Item label pill below the mannequin ──

class _ItemLabel extends StatelessWidget {
  final List<WardrobeItem> items;
  final int index;
  final String slot;

  const _ItemLabel({required this.items, required this.index, required this.slot});

  @override
  Widget build(BuildContext context) {
    final name = items.isEmpty ? '—' : (items[index].name ?? items[index].category.label);
    final count = items.length;

    return Column(
      children: [
        Text(slot.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: Colors.white30,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(name,
            style: const TextStyle(fontSize: 13, color: Colors.white,
                fontWeight: FontWeight.w600)),
        if (count > 1)
          Text('${index + 1}/$count',
              style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ],
    );
  }
}

// ── Female body silhouette painter ──

class _BodySilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final outline = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final path = Path();

    // Head
    path.addOval(Rect.fromCenter(
        center: Offset(cx, h * 0.05), width: w * 0.18, height: w * 0.22));

    // Neck
    path.moveTo(cx - w * 0.05, h * 0.08);
    path.lineTo(cx - w * 0.05, h * 0.11);
    path.lineTo(cx + w * 0.05, h * 0.11);
    path.lineTo(cx + w * 0.05, h * 0.08);

    // Torso — shoulders to waist (feminine shape)
    final torso = Path();
    torso.moveTo(cx - w * 0.05, h * 0.11);
    // Left shoulder
    torso.quadraticBezierTo(cx - w * 0.32, h * 0.12, cx - w * 0.35, h * 0.16);
    // Left arm
    torso.lineTo(cx - w * 0.38, h * 0.35);
    torso.lineTo(cx - w * 0.30, h * 0.36);
    // Left waist
    torso.lineTo(cx - w * 0.25, h * 0.22);
    torso.quadraticBezierTo(cx - w * 0.18, h * 0.40, cx - w * 0.22, h * 0.42);
    // Left hip
    torso.quadraticBezierTo(cx - w * 0.30, h * 0.46, cx - w * 0.30, h * 0.50);
    // Left leg
    torso.lineTo(cx - w * 0.25, h * 0.78);
    torso.quadraticBezierTo(cx - w * 0.24, h * 0.82, cx - w * 0.22, h * 0.85);
    // Left foot
    torso.lineTo(cx - w * 0.28, h * 0.87);
    torso.lineTo(cx - w * 0.28, h * 0.90);
    torso.lineTo(cx - w * 0.12, h * 0.90);
    torso.lineTo(cx - w * 0.12, h * 0.87);
    torso.lineTo(cx - w * 0.14, h * 0.85);

    // Inner legs
    torso.lineTo(cx - w * 0.06, h * 0.50);
    torso.lineTo(cx + w * 0.06, h * 0.50);

    // Right leg
    torso.lineTo(cx + w * 0.14, h * 0.85);
    torso.lineTo(cx + w * 0.12, h * 0.87);
    torso.lineTo(cx + w * 0.12, h * 0.90);
    torso.lineTo(cx + w * 0.28, h * 0.90);
    torso.lineTo(cx + w * 0.28, h * 0.87);
    torso.lineTo(cx + w * 0.22, h * 0.85);
    torso.quadraticBezierTo(cx + w * 0.24, h * 0.82, cx + w * 0.25, h * 0.78);
    // Right hip
    torso.lineTo(cx + w * 0.30, h * 0.50);
    torso.quadraticBezierTo(cx + w * 0.30, h * 0.46, cx + w * 0.22, h * 0.42);
    // Right waist
    torso.quadraticBezierTo(cx + w * 0.18, h * 0.40, cx + w * 0.25, h * 0.22);
    // Right arm
    torso.lineTo(cx + w * 0.30, h * 0.36);
    torso.lineTo(cx + w * 0.38, h * 0.35);
    torso.lineTo(cx + w * 0.35, h * 0.16);
    // Right shoulder
    torso.quadraticBezierTo(cx + w * 0.32, h * 0.12, cx + w * 0.05, h * 0.11);
    torso.close();

    path.addPath(torso, Offset.zero);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
