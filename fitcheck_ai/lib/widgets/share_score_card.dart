import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

import '../core/theme.dart';
import '../models/fit_check.dart';

/// Generates a shareable score card image for Instagram/TikTok
class ShareScoreCard extends StatelessWidget {
  final FitCheck fitCheck;
  final Uint8List? photo;
  final GlobalKey repaintKey;

  const ShareScoreCard({
    super.key,
    required this.fitCheck,
    this.photo,
    required this.repaintKey,
  });

  static Future<Uint8List?> capture(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF00C853);
    if (s >= 60) return const Color(0xFFFFC107);
    return const Color(0xFFFF5252);
  }

  String _scoreLabel(int s) {
    if (s >= 90) return 'FIRE 🔥';
    if (s >= 80) return 'GREAT ✨';
    if (s >= 70) return 'SOLID 👌';
    if (s >= 60) return 'OK 🤷';
    return 'MEH 😬';
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1d24), Color(0xFF0b0d10)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('GRWM',
                      style: TextStyle(color: AppTheme.primary,
                          fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                const Spacer(),
                Text(_formatDate(fitCheck.createdAt),
                    style: const TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ),

            const SizedBox(height: 20),

            // Photo + Score
            Row(
              children: [
                // Photo
                if (photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(photo!, width: 120, height: 160,
                        fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 120, height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.checkroom, color: Colors.white24, size: 40),
                  ),

                const SizedBox(width: 20),

                // Score column
                Expanded(
                  child: Column(
                    children: [
                      Text('${fitCheck.score}',
                          style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900,
                              color: _scoreColor(fitCheck.score), height: 1)),
                      Text(_scoreLabel(fitCheck.score),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                              color: _scoreColor(fitCheck.score))),
                      const SizedBox(height: 16),
                      _MiniBar(label: 'Color', value: fitCheck.colorHarmonyScore ?? 0),
                      _MiniBar(label: 'Style', value: fitCheck.styleCohesionScore ?? 0),
                      _MiniBar(label: 'Occasion', value: fitCheck.occasionScore ?? 0),
                      _MiniBar(label: 'Fit', value: fitCheck.fitScore ?? 0),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Feedback
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(fitCheck.feedback,
                  style: const TextStyle(color: Colors.white70, fontSize: 13,
                      height: 1.4),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
            ),

            const SizedBox(height: 16),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Colors.white24),
                const SizedBox(width: 6),
                const Text('Scored by AI  •  grwm.app',
                    style: TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final int value;
  const _MiniBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 80
        ? const Color(0xFF00C853)
        : value >= 60
            ? const Color(0xFFFFC107)
            : const Color(0xFFFF5252);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 52,
              child: Text(label, style: const TextStyle(fontSize: 10,
                  color: Colors.white38))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value / 100,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(width: 22,
              child: Text('$value', textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: color))),
        ],
      ),
    );
  }
}
