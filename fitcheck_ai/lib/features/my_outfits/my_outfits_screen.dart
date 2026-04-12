import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/fit_check.dart';

// ── State ────────────────────────────────────────────────

final outfitHistoryProvider =
    StateNotifierProvider<OutfitHistoryNotifier, List<FitCheck>>(
  (ref) => OutfitHistoryNotifier(),
);

class OutfitHistoryNotifier extends StateNotifier<List<FitCheck>> {
  OutfitHistoryNotifier() : super(_demoHistory);

  void add(FitCheck fc) => state = [fc, ...state];
}

final _demoHistory = <FitCheck>[
  FitCheck(
    id: 'd1',
    userId: 'demo',
    score: 87,
    feedback: 'Great color coordination! The neutrals work really well together.',
    colorHarmonyScore: 90,
    styleCohesionScore: 85,
    occasionScore: 88,
    fitScore: 84,
    improvementTips: ['Try adding a statement accessory', 'Belt would tie it together'],
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  FitCheck(
    id: 'd2',
    userId: 'demo',
    score: 72,
    feedback: 'Decent look but the shoe choice clashes a bit with the overall vibe.',
    colorHarmonyScore: 68,
    styleCohesionScore: 75,
    occasionScore: 80,
    fitScore: 65,
    improvementTips: ['Swap boots for clean sneakers', 'Tuck in the shirt for a cleaner line'],
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
];

// ── Screen ───────────────────────────────────────────────

class MyOutfitsScreen extends ConsumerStatefulWidget {
  const MyOutfitsScreen({super.key});

  @override
  ConsumerState<MyOutfitsScreen> createState() => _MyOutfitsScreenState();
}

class _MyOutfitsScreenState extends ConsumerState<MyOutfitsScreen>
    with SingleTickerProviderStateMixin {
  bool _showResult = false;
  FitCheck? _latestResult;
  late AnimationController _scoreAnim;

  @override
  void initState() {
    super.initState();
    _scoreAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _scoreAnim.dispose();
    super.dispose();
  }

  // Demo: generate a random score
  void _takePhoto() {
    final rng = Random();
    final score = 55 + rng.nextInt(41); // 55-95
    final fc = FitCheck(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'demo',
      score: score,
      feedback: _feedbackForScore(score),
      colorHarmonyScore: 50 + rng.nextInt(46),
      styleCohesionScore: 50 + rng.nextInt(46),
      occasionScore: 50 + rng.nextInt(46),
      fitScore: 50 + rng.nextInt(46),
      improvementTips: const [
        'Try a contrasting belt',
        'Roll the sleeves for a casual touch',
        'Layer with a light jacket',
      ],
      createdAt: DateTime.now(),
    );

    ref.read(outfitHistoryProvider.notifier).add(fc);

    setState(() {
      _latestResult = fc;
      _showResult = true;
    });
    _scoreAnim.forward(from: 0);
  }

  String _feedbackForScore(int s) {
    if (s >= 85) return 'Fire! This outfit is on point 🔥';
    if (s >= 75) return 'Looking great — solid color choices and good fit.';
    if (s >= 65) return 'Not bad! A small tweak or two could level this up.';
    return 'Needs a little work — check the tips below.';
  }

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF00C853);
    if (s >= 60) return const Color(0xFFFFC107);
    return const Color(0xFFFF5252);
  }

  String _scoreLabel(int s) {
    if (s >= 90) return 'FIRE 🔥';
    if (s >= 80) return 'GREAT';
    if (s >= 70) return 'SOLID';
    if (s >= 60) return 'OK';
    return 'MEH';
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(outfitHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Outfits'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _showResult ? _buildResult() : _buildMain(history),
    );
  }

  // ── Main view: camera + history ──

  Widget _buildMain(List<FitCheck> history) {
    return Column(
      children: [
        // Camera button
        GestureDetector(
          onTap: _takePhoto,
          child: Container(
            margin: const EdgeInsets.all(20),
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 40,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Take a Full Body Pic',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Get your fit scored',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // History header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${history.length} fits',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // History list
        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Text(
                    'No outfits scored yet.\nTake your first pic!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: history.length,
                  itemBuilder: (ctx, i) => _HistoryTile(fc: history[i]),
                ),
        ),
      ],
    );
  }

  // ── Score result view ──

  Widget _buildResult() {
    final fc = _latestResult!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Score circle
          AnimatedBuilder(
            animation: _scoreAnim,
            builder: (ctx, _) {
              final animScore = (_scoreAnim.value * fc.score).toInt();
              return Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _scoreColor(fc.score).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$animScore',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: _scoreColor(fc.score),
                        ),
                      ),
                      Text(
                        _scoreLabel(fc.score),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _scoreColor(fc.score),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Feedback
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              fc.feedback,
              style: const TextStyle(fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Sub-scores
          _SubScoreRow(label: 'Color Harmony', value: fc.colorHarmonyScore ?? 0),
          _SubScoreRow(label: 'Style Cohesion', value: fc.styleCohesionScore ?? 0),
          _SubScoreRow(label: 'Occasion Fit', value: fc.occasionScore ?? 0),
          _SubScoreRow(label: 'Overall Fit', value: fc.fitScore ?? 0),

          const SizedBox(height: 16),

          // Tips
          if (fc.improvementTips != null && fc.improvementTips!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Style Tips',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...fc.improvementTips!.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t, style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Back button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _showResult = false),
              child: const Text('Back to My Outfits'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final FitCheck fc;
  const _HistoryTile({required this.fc});

  Color _color(int s) {
    if (s >= 80) return const Color(0xFF00C853);
    if (s >= 60) return const Color(0xFFFFC107);
    return const Color(0xFFFF5252);
  }

  @override
  Widget build(BuildContext context) {
    final ago = DateTime.now().difference(fc.createdAt);
    String when;
    if (ago.inDays == 0) {
      when = 'Today';
    } else if (ago.inDays == 1) {
      when = 'Yesterday';
    } else {
      when = '${ago.inDays}d ago';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Score badge
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _color(fc.score).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${fc.score}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _color(fc.score),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fc.feedback,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  when,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

class _SubScoreRow extends StatelessWidget {
  final String label;
  final int value;
  const _SubScoreRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 80
        ? const Color(0xFF00C853)
        : value >= 60
            ? const Color(0xFFFFC107)
            : const Color(0xFFFF5252);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
