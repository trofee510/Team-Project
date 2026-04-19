import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../main.dart';
import '../models/wardrobe_item.dart';
import 'supabase_image.dart';

class ClothingGridTile extends StatelessWidget {
  final WardrobeItem item;
  final VoidCallback? onTap;

  const ClothingGridTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: _buildImage(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              item.name ?? item.category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildImage() {
    // Demo mode: show colored placeholder with icon
    if (kDemoMode || item.imagePath == 'demo') {
      return Container(
        width: double.infinity,
        color: _colorFromName(item.color),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.category.icon,
                size: 28,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 4),
              Text(
                item.color ?? '',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Real mode: load from Supabase storage (signed URL for private bucket).
    final path = item.thumbnailPath ?? item.imagePath;
    return SupabaseImage(
      path: path,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: Container(
        width: double.infinity,
        color: _colorFromName(item.color),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.category.icon, size: 28,
                  color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(height: 4),
              Text(item.color ?? '',
                  style: TextStyle(fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600)),
            ],
          ),
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
      'red' => Colors.red.shade400,
      'green' => Colors.green.shade400,
      _ => AppTheme.primary.withValues(alpha: 0.6),
    };
  }
}
