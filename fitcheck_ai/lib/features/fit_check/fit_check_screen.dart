import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/extensions.dart';
import '../../services/ai_proxy_service.dart';
import '../../services/analytics_service.dart';
import '../../services/fit_check_engine.dart';
import '../../services/gemini_service.dart';
import '../../services/pro_status.dart';
import '../../services/streak_service.dart';
import '../../services/usage_tracker.dart';
import '../../widgets/score_dial.dart';
import '../../widgets/share_score_card.dart';
import '../../models/fit_check.dart';

/// Result screen for a fit check. Accepts either:
///   - an outfitId to score a stored outfit, or
///   - raw image bytes to score an ad-hoc upload (instant-value flow, battles).
class FitCheckScreen extends ConsumerStatefulWidget {
  final String outfitId;
  final Uint8List? imageBytes;
  final String? occasion;

  const FitCheckScreen({
    super.key,
    required this.outfitId,
    this.imageBytes,
    this.occasion,
  });

  @override
  ConsumerState<FitCheckScreen> createState() => _FitCheckScreenState();
}

class _FitCheckScreenState extends ConsumerState<FitCheckScreen> {
  final _shareKey = GlobalKey();

  ScoredFit? _result;
  bool _isLoading = true;
  bool _isSharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runFitCheck();
  }

  Future<void> _runFitCheck() async {
    final analytics = ref.read(analyticsServiceProvider);
    final started = DateTime.now();
    analytics.track(AnalyticsService.fitCheckStarted);

    // NOTE: we do NOT pre-gate on the free-tier limit. Show the score first —
    // the paywall only locks the *detail* (sub-scores, tips, history) for
    // over-limit free users further down the screen.
    try {
      final bytes = widget.imageBytes;
      if (bytes == null) {
        throw Exception(
            'Outfit composite not available yet. Open "Fit Check" from the home tab and pick a photo.');
      }

      final engine = ref.read(fitCheckEngineProvider);
      final scored = await engine.score(
        bytes,
        occasion: widget.occasion,
        outfitId: widget.outfitId == 'instant' ? null : widget.outfitId,
      );

      if (!mounted) return;
      setState(() {
        _result = scored;
        _isLoading = false;
      });

      if (!scored.cached) {
        ref.read(usageTrackerProvider.notifier).recordFitCheck();
        ref.read(streakServiceProvider.notifier).recordScore(scored.result.score);
      }
      analytics.track(AnalyticsService.fitCheckSucceeded, props: {
        'score': scored.result.score,
        'cached': scored.cached,
        'elapsed_ms': DateTime.now().difference(started).inMilliseconds,
      });
    } on FitCheckLimitReached {
      analytics.track(AnalyticsService.fitCheckLimitHit);
      if (mounted) context.go('/paywall?reason=limit');
    } catch (e, st) {
      analytics
        ..track(AnalyticsService.fitCheckFailed,
            props: {'error': e.toString()})
        ..captureError(e, st, hint: 'fit_check_run');
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _shareScoreCard() async {
    if (_result == null || _isSharing) return;
    setState(() => _isSharing = true);
    try {
      // Give the offscreen card one frame to lay out at capture size.
      await Future.delayed(const Duration(milliseconds: 50));
      final bytes = await ShareScoreCard.capture(_shareKey);
      if (bytes == null) throw Exception('Failed to render share card');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/grwm_score_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'I scored ${_result!.result.score}/100 on GRWM — rate your fit: https://grwm.app',
      );
    } catch (e) {
      if (mounted) context.showSnackBar('Share failed: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Server-trusted Pro flag — never rely on the client-only usage tracker
    // for paid-feature gates.
    final isPro = ref.watch(proStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fit Check')),
      body: _isLoading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _runFitCheck();
                })
              : _buildResult(isPro),
    );
  }

  Widget _buildResult(bool isPro) {
    final result = _result!.result;
    final score = result.score;
    final scoreColor = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.red;

    // Free users who exceeded today's limit still see the score — but the
    // sub-scores + tips lock. This is the "moment of value" paywall.
    final canDoFitCheck = ref.watch(usageTrackerProvider).canDoFitCheck;
    final detailLocked = !isPro && !canDoFitCheck;

    // Build a lightweight FitCheck for the share card widget.
    final previewCheck = FitCheck(
      id: _result!.id ?? 'preview',
      userId: '',
      score: score,
      feedback: result.feedback,
      colorHarmonyScore: result.colorHarmony,
      styleCohesionScore: result.styleCohesion,
      occasionScore: result.occasionFit,
      fitScore: result.versatility,
      improvementTips: result.tips,
      createdAt: DateTime.now(),
    );

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              ScoreDial(score: score, color: scoreColor, size: 180),
              const SizedBox(height: 8),
              Text(
                _scoreLabel(score),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
              if (_result!.cached)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Same outfit → same score. Reproducibility on.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              _LockedIfFree(
                locked: detailLocked,
                reason: 'sub_scores',
                ctaText: 'Unlock breakdown',
                child: _breakdownCard(result),
              ),
              const SizedBox(height: 16),
              _feedbackCard(result.feedback),
              if (result.tips.isNotEmpty) ...[
                const SizedBox(height: 16),
                _LockedIfFree(
                  locked: detailLocked,
                  reason: 'tips',
                  ctaText: 'Unlock 3 personalized tips',
                  child: _tipsCard(result.tips),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : _shareScoreCard,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.share),
                  label: Text(_isSharing ? 'Generating...' : 'Share my score'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.push(
                      '/battle/new',
                      extra: widget.imageBytes,
                    );
                  },
                  icon: const Icon(Icons.group),
                  label: const Text('Ask friends to rate it too'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),

        // Offscreen share card — used only for PNG capture.
        Positioned(
          left: -10000,
          child: RepaintBoundary(
            key: _shareKey,
            child: Material(
              color: Colors.transparent,
              child: ShareScoreCard(
                fitCheck: previewCheck,
                photo: widget.imageBytes,
                repaintKey: _shareKey,
                showWatermark: !isPro,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _breakdownCard(FullFitResult r) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _SubScoreBar(label: 'Color Harmony', score: r.colorHarmony, icon: Icons.palette),
          _SubScoreBar(label: 'Style Cohesion', score: r.styleCohesion, icon: Icons.auto_awesome),
          _SubScoreBar(label: 'Occasion Fit', score: r.occasionFit, icon: Icons.event),
          _SubScoreBar(label: 'Versatility', score: r.versatility, icon: Icons.swap_horiz),
        ],
      ),
    );
  }

  Widget _feedbackCard(String feedback) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('AI Feedback',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            feedback,
            style: const TextStyle(
                fontSize: 15, height: 1.6, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _tipsCard(List<String> tips) {
    return Container(
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
              Text('Style Tips',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700)),
                    Expanded(
                      child: Text(tip,
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
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
      child: child,
    );
  }

  String _scoreLabel(int score) {
    if (score >= 90) return 'Fire!';
    if (score >= 80) return 'Looking Great!';
    if (score >= 70) return 'Solid Fit';
    if (score >= 60) return 'Not Bad';
    return 'Needs Work';
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.accent),
          SizedBox(height: 20),
          Text(
            'Scoring your fit...',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Overlay that blurs + locks a child for over-limit free users. Tap → paywall
/// with the specific `reason` so the headline matches the moment.
class _LockedIfFree extends StatelessWidget {
  final bool locked;
  final Widget child;
  final String reason;
  final String ctaText;

  const _LockedIfFree({
    required this.locked,
    required this.child,
    required this.reason,
    required this.ctaText,
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(
      children: [
        // Muted preview — gives users a taste of what's gated.
        Opacity(opacity: 0.25, child: IgnorePointer(child: child)),
        Positioned.fill(
          child: GestureDetector(
            onTap: () => context.push('/paywall?reason=$reason'),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                ),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, color: AppTheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    ctaText,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final IconData icon;

  const _SubScoreBar(
      {required this.label, required this.score, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13))),
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
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13, color: color),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
