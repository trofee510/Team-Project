import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

import '../core/theme.dart';
import '../models/fit_check.dart';

/// Portrait 9:16 score card for Instagram Stories / TikTok share.
/// Designed to render at 1080x1920 with pixelRatio 3.0 from a 360x640 layout.
class ShareScoreCard extends StatelessWidget {
  final FitCheck fitCheck;
  final Uint8List? photo;
  final GlobalKey repaintKey;
  final bool showWatermark;

  const ShareScoreCard({
    super.key,
    required this.fitCheck,
    this.photo,
    required this.repaintKey,
    this.showWatermark = true,
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
    final score = fitCheck.score;
    final scoreColor = _scoreColor(score);

    return RepaintBoundary(
      key: repaintKey,
      child: SizedBox(
        width: 360,
        height: 640, // 9:16
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1a1d24), Color(0xFF0b0d10)],
                ),
              ),
            ),

            // Faint accent glow
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Photo — hero
            if (photo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 280),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(photo!, fit: BoxFit.cover),
                ),
              ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'GRWM',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(fitCheck.createdAt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Bottom score panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0b0d10).withValues(alpha: 0),
                      const Color(0xFF0b0d10),
                      const Color(0xFF0b0d10),
                    ],
                    stops: const [0, 0.25, 1],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 96,
                            fontWeight: FontWeight.w900,
                            color: scoreColor,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(
                            '/100',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            _scoreLabel(score),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: scoreColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _MiniBar(label: 'Color',    value: fitCheck.colorHarmonyScore ?? 0),
                    _MiniBar(label: 'Style',    value: fitCheck.styleCohesionScore ?? 0),
                    _MiniBar(label: 'Occasion', value: fitCheck.occasionScore ?? 0),
                    _MiniBar(label: 'Fit',      value: fitCheck.fitScore ?? 0),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome, size: 13, color: Colors.white38),
                        const SizedBox(width: 6),
                        Text(
                          showWatermark
                              ? 'Scored by AI  •  grwm.app'
                              : 'grwm.app',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Diagonal watermark for free tier
            if (showWatermark)
              Positioned(
                top: 120,
                right: -20,
                child: Transform.rotate(
                  angle: 0.35,
                  child: Text(
                    'GRWM',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.08),
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
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
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value / 100,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 26,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
