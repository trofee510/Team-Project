import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/extensions.dart';
import '../../core/theme.dart';
import '../../models/fit_battle.dart';
import '../../services/battle_service.dart';
import '../../services/supabase_service.dart';

/// Public-facing battle view. Friends open this via deep link.
/// If signed in (or anon auth), they can rate; otherwise prompt sign-in.
class BattleViewScreen extends ConsumerStatefulWidget {
  final String code;
  const BattleViewScreen({super.key, required this.code});

  @override
  ConsumerState<BattleViewScreen> createState() => _BattleViewScreenState();
}

class _BattleViewScreenState extends ConsumerState<BattleViewScreen> {
  BattleSummary? _summary;
  bool _loading = true;
  String? _error;

  int _myScore = 75;
  final _nameCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  bool _rated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(battleServiceProvider).getByCode(widget.code);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _loading = false;
        _error = s == null ? 'Battle not found' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submitRating() async {
    if (_nameCtrl.text.trim().isEmpty) {
      context.showSnackBar('Add your name so they know who rated them');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(battleServiceProvider).rate(
            battleId: _summary!.battle.id,
            score: _myScore,
            raterName: _nameCtrl.text,
            comment: _commentCtrl.text,
          );
      await _load();
      if (!mounted) return;
      setState(() {
        _rated = true;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      context.showSnackBar('Rating failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Battle ${widget.code}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _content(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_dissatisfied,
                size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final s = _summary!;
    final battle = s.battle;
    final supabase = ref.read(supabaseServiceProvider);
    final imageUrl = supabase.getPublicUrl(battle.imagePath);
    final isOwner = supabase.currentUser?.id == battle.userId;
    final isExpired = battle.isExpired;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Owner line
          Row(
            children: [
              const Icon(Icons.person_pin, size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                isOwner ? 'Your battle' : 'Rate their fit',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (isExpired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Expired',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Image
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey.shade200),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),

          if (battle.caption != null && battle.caption!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('"${battle.caption}"',
                style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary)),
          ],

          const SizedBox(height: 20),

          // Live aggregate
          _aggregatePanel(s),

          const SizedBox(height: 24),

          if (!isOwner && !isExpired && !_rated) _ratingPanel(),

          if (_rated) _thankYouPanel(),

          const SizedBox(height: 24),

          if (s.ratings.isNotEmpty) ...[
            const Text('Everyone\'s takes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...s.ratings.map(_ratingTile),
          ],

          const SizedBox(height: 32),

          if (isOwner)
            OutlinedButton.icon(
              onPressed: () async {
                final url = ref
                    .read(battleServiceProvider)
                    .shareUrl(battle.code);
                await Share.share(
                    'Rate my fit — 1 tap, no signup needed 👀\n$url');
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('Share again'),
            ),
        ],
      ),
    );
  }

  Widget _aggregatePanel(BattleSummary s) {
    final avg = s.averageScore;
    final n = s.ratingCount;
    final aiScore = s.battle.aiScore;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _scorePill(
            label: 'FRIENDS',
            value: avg == null ? '—' : avg.toStringAsFixed(0),
            sub: n == 0
                ? 'No votes yet'
                : '$n vote${n == 1 ? '' : 's'}',
            color: AppTheme.accent,
          ),
          const SizedBox(width: 16),
          _scorePill(
            label: 'AI',
            value: aiScore?.toString() ?? '—',
            sub: 'GRWM',
            color: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _scorePill({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1)),
            const SizedBox(height: 4),
            Text(sub,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _ratingPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your rating',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 1,
                  max: 100,
                  divisions: 99,
                  value: _myScore.toDouble(),
                  label: '$_myScore',
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _myScore = v.round()),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '$_myScore',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Your name',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _commentCtrl,
            maxLength: 140,
            decoration: const InputDecoration(
              labelText: 'One line of feedback (optional)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitRating,
              child: Text(_submitting ? 'Submitting...' : 'Submit rating'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thankYouPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Thanks for rating! Want scores on your own fits? '
              'Install GRWM — free.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingTile(BattleRating r) {
    final color = r.score >= 80
        ? Colors.green
        : r.score >= 60
            ? Colors.orange
            : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '${r.score}',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.raterName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (r.comment != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      r.comment!,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
