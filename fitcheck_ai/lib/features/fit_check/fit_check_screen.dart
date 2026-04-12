import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/extensions.dart';
import '../../services/usage_tracker.dart';
import '../../widgets/score_dial.dart';

class FitCheckScreen extends ConsumerStatefulWidget {
  final String outfitId;

  const FitCheckScreen({super.key, required this.outfitId});

  @override
  ConsumerState<FitCheckScreen> createState() => _FitCheckScreenState();
}

class _FitCheckScreenState extends ConsumerState<FitCheckScreen> {
  _EnhancedFitResult? _result;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runFitCheck();
  }

  Future<void> _runFitCheck() async {
    final tracker = ref.read(usageTrackerProvider.notifier);
    if (!tracker.canDoFitCheck()) {
      if (mounted) context.go('/paywall');
      return;
    }

    try {
      // TODO: When API keys are set, composite outfit images and call Gemini
      // For now, generate rich demo data
      await Future.delayed(const Duration(seconds: 2));

      final rng = Random();
      final overall = 65 + rng.nextInt(30);

      setState(() {
        _result = _EnhancedFitResult(
          score: overall,
          feedback: 'Great color coordination! The tones complement each other '
              'well. Consider adding a subtle accessory to elevate the overall look.',
          colorHarmony: 60 + rng.nextInt(35),
          styleCohesion: 60 + rng.nextInt(35),
          occasionFit: 60 + rng.nextInt(35),
          versatility: 60 + rng.nextInt(35),
          tips: [
            'Try a belt to add structure to the silhouette',
            'A watch or bracelet would complement this nicely',
            'These colors work well for both day and evening',
          ],
        );
        _isLoading = false;
      });
      tracker.recordFitCheck();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fit Check')),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  SizedBox(height: 20),
                  Text(
                    'Analyzing your outfit...',
                    style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _buildResult(),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    final scoreColor = result.score >= 80
        ? Colors.green
        : result.score >= 60
            ? Colors.orange
            : Colors.red;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Animated score dial
          ScoreDial(score: result.score, color: scoreColor, size: 180),

          const SizedBox(height: 8),
          Text(
            _getScoreLabel(result.score),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: scoreColor,
            ),
          ),

          const SizedBox(height: 28),

          // Sub-score breakdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _SubScoreBar(label: 'Color Harmony', score: result.colorHarmony, icon: Icons.palette),
                _SubScoreBar(label: 'Style Cohesion', score: result.styleCohesion, icon: Icons.auto_awesome),
                _SubScoreBar(label: 'Occasion Fit', score: result.occasionFit, icon: Icons.event),
                _SubScoreBar(label: 'Versatility', score: result.versatility, icon: Icons.swap_horiz),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Feedback card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text('AI Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  result.feedback,
                  style: const TextStyle(fontSize: 15, height: 1.6, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Tips
          if (result.tips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tips_and_updates, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Style Tips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...result.tips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                            Expanded(
                              child: Text(tip, style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textSecondary)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Share button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.showSnackBar('Share card coming soon!');
              },
              icon: const Icon(Icons.share),
              label: const Text('Share Score'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getScoreLabel(int score) {
    if (score >= 90) return 'Fire!';
    if (score >= 80) return 'Looking Great!';
    if (score >= 70) return 'Solid Fit';
    if (score >= 60) return 'Not Bad';
    return 'Needs Work';
  }
}

class _SubScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final IconData icon;

  const _SubScoreBar({required this.label, required this.score, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80 ? Colors.green : score >= 60 ? Colors.orange : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            child: Text(
              '$score',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnhancedFitResult {
  final int score;
  final String feedback;
  final int colorHarmony;
  final int styleCohesion;
  final int occasionFit;
  final int versatility;
  final List<String> tips;

  _EnhancedFitResult({
    required this.score,
    required this.feedback,
    required this.colorHarmony,
    required this.styleCohesion,
    required this.occasionFit,
    required this.versatility,
    this.tips = const [],
  });
}
