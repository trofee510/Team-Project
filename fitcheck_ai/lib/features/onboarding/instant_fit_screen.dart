import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/fit_check.dart';
import '../../services/gemini_service.dart';
import '../../widgets/score_dial.dart';
import '../../widgets/share_score_card.dart';

/// Runs a real Gemini fit check on the pre-signup path. No Supabase write —
/// we keep everything in-memory, show the score, then gate "save it" on
/// signup. This is the 30-second aha moment.
class InstantFitScreen extends ConsumerStatefulWidget {
  final Uint8List imageBytes;
  const InstantFitScreen({super.key, required this.imageBytes});

  @override
  ConsumerState<InstantFitScreen> createState() => _InstantFitScreenState();
}

class _InstantFitScreenState extends ConsumerState<InstantFitScreen> {
  FullFitResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final gemini = ref.read(geminiServiceProvider);
      final r = await gemini.scoreFitCheck(widget.imageBytes);
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your first score'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/welcome'),
        ),
      ),
      body: _loading
          ? _loadingView()
          : _error != null
              ? _errorView()
              : _scoreView(),
    );
  }

  Widget _loadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text('Reading the room...',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/welcome'),
              child: const Text('Try another photo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreView() {
    final r = _result!;
    final color = r.score >= 80
        ? Colors.green
        : r.score >= 60
            ? Colors.orange
            : Colors.red;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              widget.imageBytes,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          ScoreDial(score: r.score, color: color, size: 160),
          const SizedBox(height: 6),
          Text(_label(r.score),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 20),

          _sub('Color harmony', r.colorHarmony),
          _sub('Style cohesion', r.styleCohesion),
          _sub('Occasion fit', r.occasionFit),
          _sub('Versatility', r.versatility),

          const SizedBox(height: 20),
          if (r.feedback.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                r.feedback,
                style: const TextStyle(height: 1.5),
              ),
            ),

          const SizedBox(height: 24),
          const _Teaser(),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/auth'),
              icon: const Icon(Icons.bookmark_add),
              label: const Text('Save & unlock streaks'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              // Let the user try another photo without any gate.
              context.go('/welcome');
            },
            child: const Text('Score another fit'),
          ),
          const SizedBox(height: 20),

          // Offscreen card reference — confirms share flow compiles against
          // the real widget even on the pre-signup path. Not rendered.
          Offstage(
            offstage: true,
            child: ShareScoreCard(
              fitCheck: FitCheck(
                id: 'instant',
                userId: '',
                score: r.score,
                feedback: r.feedback,
                colorHarmonyScore: r.colorHarmony,
                styleCohesionScore: r.styleCohesion,
                occasionScore: r.occasionFit,
                fitScore: r.versatility,
                improvementTips: r.tips,
                createdAt: DateTime.now(),
              ),
              repaintKey: GlobalKey(),
              showWatermark: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sub(String label, int v) {
    final c = v >= 80
        ? Colors.green
        : v >= 60
            ? Colors.orange
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: v / 100,
                backgroundColor: Colors.grey.shade200,
                color: c,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            child: Text(
              '$v',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c),
            ),
          ),
        ],
      ),
    );
  }

  String _label(int s) {
    if (s >= 90) return 'Fire!';
    if (s >= 80) return 'Looking great';
    if (s >= 70) return 'Solid fit';
    if (s >= 60) return 'Not bad';
    return 'Needs work';
  }
}

class _Teaser extends StatelessWidget {
  const _Teaser();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _Line(
              icon: Icons.share,
              text: 'Share a 9:16 score card to stories'),
          _Line(
              icon: Icons.group,
              text: 'Ask friends to rate your fit too'),
          _Line(
              icon: Icons.local_fire_department,
              text: 'Daily streak for rating your outfit'),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Line({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
