import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/extensions.dart';
import '../../main.dart';
import '../../models/wardrobe_item.dart';
import 'wardrobe_controller.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final WardrobeItem item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  String? _signedUrl;
  bool _loadingUrl = true;

  WardrobeItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
  }

  Future<void> _loadImageUrl() async {
    if (kDemoMode || item.imagePath == 'demo') {
      setState(() => _loadingUrl = false);
      return;
    }
    try {
      final url = await Supabase.instance.client.storage
          .from(AppConstants.wardrobeBucket)
          .createSignedUrl(item.imagePath, 3600);
      if (mounted) setState(() { _signedUrl = url; _loadingUrl = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingUrl = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // Image (tap for fullscreen)
            Center(
              child: GestureDetector(
                onTap: _signedUrl != null ? () => _showFullImage(context) : null,
                child: Container(
                  width: 300,
                  height: 350,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: _buildImage(),
                      ),
                      if (_signedUrl != null)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
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

  void _showFullImage(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Scaffold(
            backgroundColor: Colors.black87,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                item.name ?? item.category.label,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  _signedUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image, color: Colors.white54, size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (kDemoMode || item.imagePath == 'demo') return _placeholder();

    if (_loadingUrl) {
      return const Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_signedUrl == null) return _placeholder();

    return Image.network(
      _signedUrl!,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.category.icon, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(
            item.category.label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
