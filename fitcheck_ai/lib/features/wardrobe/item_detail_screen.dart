import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/extensions.dart';
import '../../models/wardrobe_item.dart';
import 'wardrobe_controller.dart';

class ItemDetailScreen extends ConsumerWidget {
  final WardrobeItem item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name ?? item.category.label),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Item?'),
                  content: const Text('This will permanently remove this item from your wardrobe.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref.read(wardrobeControllerProvider.notifier).deleteItem(item);
                if (context.mounted) {
                  context.showSnackBar('Item deleted');
                  context.pop();
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: _colorFromName(item.color),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.category.icon, size: 56,
                          color: Colors.white.withValues(alpha: 0.9)),
                      const SizedBox(height: 8),
                      Text(
                        item.color ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Details
            _DetailRow(label: 'Category', value: item.category.label),
            if (item.subcategory != null)
              _DetailRow(label: 'Type', value: item.subcategory!),
            if (item.color != null)
              _DetailRow(label: 'Color', value: item.color!),
            if (item.brand != null)
              _DetailRow(label: 'Brand', value: item.brand!),
            if (item.season != null)
              _DetailRow(label: 'Season', value: item.season!),

            const SizedBox(height: 24),

            // Stats
            Row(
              children: [
                _StatChip(
                  icon: Icons.repeat,
                  value: '${item.wearCount}',
                  label: 'Times Worn',
                ),
                const SizedBox(width: 12),
                if (item.purchasePrice != null)
                  _StatChip(
                    icon: Icons.attach_money,
                    value: '\$${item.purchasePrice!.toStringAsFixed(0)}',
                    label: 'Price',
                  ),
                if (item.costPerWear != null) ...[
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.trending_down,
                    value: '\$${item.costPerWear!.toStringAsFixed(2)}',
                    label: 'Cost/Wear',
                  ),
                ],
              ],
            ),

            if (item.tags != null && item.tags!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: item.tags!.map((t) => Chip(label: Text(t))).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _colorFromName(String? colorName) {
    return switch (colorName?.toLowerCase()) {
      'white' => Colors.blueGrey.shade200,
      'black' => Colors.grey.shade800,
      'dark blue' || 'navy' => Colors.indigo.shade400,
      'light blue' => Colors.lightBlue.shade300,
      'khaki' || 'beige' => Colors.amber.shade300,
      'brown' => Colors.brown.shade400,
      'silver' || 'grey' || 'gray' => Colors.blueGrey.shade300,
      _ => AppTheme.primary.withValues(alpha: 0.6),
    };
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
