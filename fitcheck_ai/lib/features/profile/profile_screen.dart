import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../main.dart';
import '../wardrobe/wardrobe_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobeAsync = ref.watch(wardrobeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar + name
            CircleAvatar(
              radius: 44,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.person, size: 44, color: AppTheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              kDemoMode ? 'Demo User' : 'User',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'FREE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary),
              ),
            ),

            const SizedBox(height: 32),

            // Stats grid
            wardrobeAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (items) {
                final categories = <String, int>{};
                final colors = <String, int>{};
                int neverWorn = 0;

                for (final item in items) {
                  categories[item.category.label] =
                      (categories[item.category.label] ?? 0) + 1;
                  if (item.color != null) {
                    colors[item.color!] = (colors[item.color!] ?? 0) + 1;
                  }
                  if (item.wearCount == 0) neverWorn++;
                }

                return Column(
                  children: [
                    // Stat cards row
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.checkroom,
                          value: '${items.length}',
                          label: 'Items',
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.category,
                          value: '${categories.length}',
                          label: 'Categories',
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.warning_amber,
                          value: '$neverWorn',
                          label: 'Never Worn',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Category breakdown
                    _SectionHeader(title: 'Wardrobe Breakdown'),
                    const SizedBox(height: 12),
                    ...categories.entries.map((e) => _BreakdownRow(
                          label: e.key,
                          count: e.value,
                          total: items.length,
                        )),

                    const SizedBox(height: 24),

                    // Top colors
                    _SectionHeader(title: 'Top Colors'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colors.entries.take(8).map((e) => Chip(
                            label: Text('${e.key} (${e.value})'),
                          )).toList(),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Upgrade banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    'Upgrade to Pro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unlimited outfits, no watermarks, weather-based daily picks',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/paywall'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                    ),
                    child: const Text('See Plans'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700)),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;

  const _BreakdownRow({required this.label, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 14))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primary,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('$count', style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
