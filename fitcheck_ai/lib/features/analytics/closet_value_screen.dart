import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/extensions.dart';
import '../../core/theme.dart';
import '../../services/wardrobe_stats_service.dart';
import '../../widgets/supabase_image.dart';

class ClosetValueScreen extends ConsumerStatefulWidget {
  const ClosetValueScreen({super.key});

  @override
  ConsumerState<ClosetValueScreen> createState() => _ClosetValueScreenState();
}

class _ClosetValueScreenState extends ConsumerState<ClosetValueScreen> {
  WardrobeStatsSummary? _summary;
  bool _loading = true;
  String? _error;
  final _deadShareKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(wardrobeStatsServiceProvider).compute();
      if (!mounted) return;
      setState(() {
        _summary = s;
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

  Future<void> _shareDead() async {
    if (_summary == null || _summary!.deadItems.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 40));
      final boundary = _deadShareKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('render missing');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) throw Exception('png encode failed');

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/grwm_dead_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            '${_summary!.deadItems.length} items I never wear — rebuild the closet with GRWM',
      );
    } catch (e) {
      if (mounted) context.showSnackBar('Share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Closet value')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _content(),
    );
  }

  Widget _content() {
    final s = _summary!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _statRow(s),
          const SizedBox(height: 20),

          if (s.bestValue.isNotEmpty) ...[
            const _SectionTitle('Best value ($/wear)'),
            ...s.bestValue.map((e) => _CpwTile(entry: e, good: true)),
            const SizedBox(height: 20),
          ],
          if (s.worstValue.isNotEmpty) ...[
            const _SectionTitle('Collecting dust'),
            ...s.worstValue.map((e) => _CpwTile(entry: e, good: false)),
            const SizedBox(height: 20),
          ],

          if (s.deadItems.isNotEmpty) _deadSection(s),
          const SizedBox(height: 32),

          // Hidden share card (measured offscreen for PNG capture).
          Offstage(
            offstage: true,
            child: RepaintBoundary(
              key: _deadShareKey,
              child: Material(
                color: Colors.transparent,
                child: _DeadShareCard(count: s.deadItems.length),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(WardrobeStatsSummary s) {
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: 'Closet value',
            value: '\$${s.totalClosetValue.toStringAsFixed(0)}',
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            label: 'Avg \$/wear',
            value: s.avgCostPerWear > 0
                ? '\$${s.avgCostPerWear.toStringAsFixed(2)}'
                : '—',
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            label: 'Dead items',
            value: '${s.deadItems.length}',
            color: s.deadItems.isEmpty ? Colors.green : Colors.redAccent,
          ),
        ),
      ],
    );
  }

  Widget _deadSection(WardrobeStatsSummary s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                "${s.deadItems.length} items with 0 wears in 90 days",
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...s.deadItems.take(6).map(_deadTile),
          if (s.deadItems.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+ ${s.deadItems.length - 6} more',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sharing ? null : _shareDead,
              icon: _sharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: Text(_sharing ? 'Generating...' : 'Share this callout'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deadTile(DeadItem d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SupabaseImage(
            path: d.item.imagePath,
            width: 40,
            height: 40,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              d.item.name ?? d.item.category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${d.daysOwned}d owned',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CpwTile extends StatelessWidget {
  final CostPerWearEntry entry;
  final bool good;

  const _CpwTile({required this.entry, required this.good});

  @override
  Widget build(BuildContext context) {
    final color = good ? Colors.green : Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SupabaseImage(
            path: entry.item.imagePath,
            width: 44,
            height: 44,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.item.name ?? entry.item.category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '\$${entry.totalSpent.toStringAsFixed(0)} · '
                  '${entry.wearCount} wears',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '\$${entry.costPerWear.toStringAsFixed(2)}',
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DeadShareCard extends StatelessWidget {
  final int count;

  const _DeadShareCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 640,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a1d24), Color(0xFF0b0d10)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('GRWM',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1)),
            ),
            const Spacer(),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 140,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'items I never wear',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '0 wears in 90 days.\nTime to rebuild the closet.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.3,
              ),
            ),
            const Spacer(),
            const Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: Colors.white38),
                SizedBox(width: 6),
                Text(
                  'grwm.app  ·  your closet, quantified',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
