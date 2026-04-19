import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/category.dart';
import '../../models/wardrobe_item.dart';
import '../../services/streak_service.dart';
import '../../services/weather_service.dart';
import '../wardrobe/wardrobe_controller.dart';

class StyleAnalyticsScreen extends ConsumerStatefulWidget {
  const StyleAnalyticsScreen({super.key});

  @override
  ConsumerState<StyleAnalyticsScreen> createState() =>
      _StyleAnalyticsScreenState();
}

class _StyleAnalyticsScreenState extends ConsumerState<StyleAnalyticsScreen> {
  WeatherData? _weather;
  bool _loadingWeather = true;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final ws = ref.read(weatherServiceProvider);
    final data = await ws.getCurrentWeather();
    if (mounted) {
      setState(() {
        _weather = data;
        _loadingWeather = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(streakServiceProvider);
    final wardrobeAsync = ref.watch(wardrobeControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0b0d10),
      appBar: AppBar(title: const Text('Style Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Weather card ──
            _buildWeatherCard(),

            const SizedBox(height: 16),

            // ── Streak + Stats row ──
            Row(
              children: [
                Expanded(child: _StatCard(
                  icon: '🔥', label: 'Streak',
                  value: '${streak.currentStreak}',
                  sub: streak.scoredToday ? 'Scored today!' : 'Score a fit!',
                  color: streak.scoredToday
                      ? const Color(0xFF00C853) : const Color(0xFFFFC107),
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(
                  icon: '🎯', label: 'Avg Score',
                  value: streak.avgScore > 0
                      ? streak.avgScore.toStringAsFixed(1) : '—',
                  sub: '${streak.totalScored} fits scored',
                  color: AppTheme.primary,
                )),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _StatCard(
                  icon: '🏆', label: 'Best Streak',
                  value: '${streak.longestStreak}',
                  sub: 'days in a row',
                  color: const Color(0xFFFFD700),
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(
                  icon: '📊', label: 'Daily Target',
                  value: '${streak.dailyTarget}+',
                  sub: 'score to beat',
                  color: AppTheme.accent,
                )),
              ],
            ),

            const SizedBox(height: 16),

            // ── Closet value CTA ──
            InkWell(
              onTap: () => context.push('/closet-value'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Closet value',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Cost-per-wear & dead items',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Wardrobe breakdown ──
            const Text('Your Wardrobe',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 12),

            wardrobeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e',
                  style: const TextStyle(color: Colors.white54)),
              data: (items) => _buildWardrobeBreakdown(items),
            ),

            const SizedBox(height: 24),

            // ── Color analysis ──
            wardrobeAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) => _buildColorAnalysis(items),
            ),

            const SizedBox(height: 24),

            // ── Wear This Today ──
            if (_weather != null)
              wardrobeAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (items) => _buildWearToday(items),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    if (_loadingWeather) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1a1d24),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_weather == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1d24),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Text('🌤️', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Text('Weather unavailable',
                style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    final w = _weather!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1a1d24),
            AppTheme.primary.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(w.icon, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(w.tempDisplay,
                        style: const TextStyle(fontSize: 24,
                            fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(width: 8),
                    Text(w.condition,
                        style: const TextStyle(color: Colors.white54,
                            fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(w.dressAdvice,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text(w.city,
                    style: const TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardrobeBreakdown(List<WardrobeItem> items) {
    final counts = <ClothingCategory, int>{};
    for (final item in items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) {
      return const Text('No items yet',
          style: TextStyle(color: Colors.white38));
    }

    final max = sorted.first.value;

    return Column(
      children: sorted.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(width: 90,
                child: Row(
                  children: [
                    Icon(e.key.icon, size: 16, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text(e.key.label,
                        style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.value / max,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 24,
                child: Text('${e.value}', textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700, color: Colors.white))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorAnalysis(List<WardrobeItem> items) {
    final colorCounts = <String, int>{};
    for (final item in items) {
      final c = item.color?.toLowerCase() ?? 'unknown';
      colorCounts[c] = (colorCounts[c] ?? 0) + 1;
    }

    final sorted = colorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Top Colors',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sorted.take(8).map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _colorFromName(e.key),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text('${_capitalize(e.key)} (${e.value})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _colorFromName(e.key).computeLuminance() > 0.5
                        ? Colors.black87 : Colors.white,
                  )),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWearToday(List<WardrobeItem> items) {
    final w = _weather!;
    final categories = w.suggestedCategories;

    final suggestions = <WardrobeItem>[];
    for (final cat in categories) {
      final catItems = items
          .where((i) => i.category.name == cat)
          .toList();
      if (catItems.isNotEmpty) {
        catItems.shuffle();
        suggestions.add(catItems.first);
      }
    }

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Wear This Today',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(width: 8),
            Text(w.icon, style: const TextStyle(fontSize: 16)),
          ],
        ),
        const SizedBox(height: 4),
        Text(w.dressAdvice,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final item = suggestions[i];
              return Container(
                width: 90,
                decoration: BoxDecoration(
                  color: _colorFromName(item.color?.toLowerCase() ?? 'unknown'),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.category.icon, size: 28,
                        color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(height: 6),
                    Text(item.name ?? item.category.label,
                        style: const TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w600, color: Colors.white),
                        textAlign: TextAlign.center, maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Color _colorFromName(String name) {
    return switch (name.toLowerCase()) {
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
      _ => AppTheme.primary.withValues(alpha: 0.6),
    };
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1d24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const Spacer(),
              Text(label, style: const TextStyle(fontSize: 11,
                  color: Colors.white38, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
              color: color)),
          Text(sub, style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }
}
