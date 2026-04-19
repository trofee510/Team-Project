import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions.dart';
import '../../core/theme.dart';
import '../../services/feed_service.dart';
import '../../services/supabase_service.dart';

class StrangerFeedScreen extends ConsumerStatefulWidget {
  const StrangerFeedScreen({super.key});

  @override
  ConsumerState<StrangerFeedScreen> createState() => _StrangerFeedScreenState();
}

class _StrangerFeedScreenState extends ConsumerState<StrangerFeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Rate'),
            Tab(text: 'Top 25'),
            Tab(text: 'Challenges'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _RateQueue(),
          _Leaderboard(),
          _Challenges(),
        ],
      ),
    );
  }
}

// ─── Rate queue ─────────────────────────────────────────────

class _RateQueue extends ConsumerStatefulWidget {
  const _RateQueue();

  @override
  ConsumerState<_RateQueue> createState() => _RateQueueState();
}

class _RateQueueState extends ConsumerState<_RateQueue> {
  List<FeedItem> _queue = [];
  int _index = 0;
  bool _loading = true;
  int _score = 75;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(feedServiceProvider).fetchQueue();
      if (!mounted) return;
      setState(() {
        _queue = items;
        _index = 0;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submit() async {
    if (_index >= _queue.length) return;
    final item = _queue[_index];
    try {
      await ref.read(feedServiceProvider).rate(item.fitCheckId, _score);
    } catch (e) {
      if (mounted) context.showSnackBar('Rating failed: $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      _index++;
      _score = 75;
    });
  }

  void _skip() {
    if (!mounted) return;
    setState(() {
      _index++;
      _score = 75;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_index >= _queue.length) {
      return _EmptyQueue(onRefresh: _load);
    }

    final item = _queue[_index];
    final supabase = ref.read(supabaseServiceProvider);
    final imageUrl = supabase.getPublicUrl(item.imagePath);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: Colors.grey.shade200),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image),
                  ),
                ),
                if (item.challengeTitle != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '🏆 ${item.challengeTitle}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'AI: ${item.aiScore}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 1,
                  max: 100,
                  divisions: 99,
                  value: _score.toDouble(),
                  label: '$_score',
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _score = v.round()),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$_score',
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _skip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text('Rate  ·  $_score'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_index + 1} / ${_queue.length}',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyQueue({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.checklist_rtl,
                size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text("You're all caught up!",
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Share your own fit — or check back in a bit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Leaderboard ────────────────────────────────────────────

class _Leaderboard extends ConsumerStatefulWidget {
  const _Leaderboard();

  @override
  ConsumerState<_Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends ConsumerState<_Leaderboard> {
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(feedServiceProvider).leaderboard();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ref.read(feedServiceProvider).leaderboard();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<LeaderboardEntry>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final entries = snap.data ?? const [];
          if (entries.isEmpty) {
            return const Center(child: Text('No leaderboard yet — check back soon.'));
          }
          final supabase = ref.read(supabaseServiceProvider);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final e = entries[i];
              return _LeaderTile(
                rank: i + 1,
                entry: e,
                imageUrl: supabase.getPublicUrl(e.imagePath),
              );
            },
          );
        },
      ),
    );
  }
}

class _LeaderTile extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final String imageUrl;

  const _LeaderTile({
    required this.rank,
    required this.entry,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: rank <= 3 ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 60,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${entry.avgRating.toStringAsFixed(1)} avg',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  '${entry.ratingCount} votes  •  AI: ${entry.aiScore}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Challenges ─────────────────────────────────────────────

class _Challenges extends ConsumerStatefulWidget {
  const _Challenges();

  @override
  ConsumerState<_Challenges> createState() => _ChallengesState();
}

class _ChallengesState extends ConsumerState<_Challenges> {
  late Future<List<Challenge>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(feedServiceProvider).activeChallenges();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Challenge>>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No active challenges. New drops every Monday.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final c = list[i];
            return _ChallengeCard(challenge: c);
          },
        );
      },
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final days = challenge.endDate.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.accent],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                challenge.theme?.toUpperCase() ?? 'CHALLENGE',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                days <= 0 ? 'Ending today' : '${days}d left',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            challenge.title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800),
          ),
          if (challenge.description != null) ...[
            const SizedBox(height: 6),
            Text(
              challenge.description!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
          const SizedBox(height: 14),
          // TODO(ben): wire "enter challenge" to instant-fit flow with
          // challenge_id prefilled. Keeping the CTA visible for now so the
          // mechanic is tappable from day one.
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Enter challenge'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
