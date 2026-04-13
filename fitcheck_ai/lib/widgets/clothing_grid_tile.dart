import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../main.dart';
import '../models/wardrobe_item.dart';

class ClothingGridTile extends StatefulWidget {
  final WardrobeItem item;
  final VoidCallback? onTap;

  const ClothingGridTile({super.key, required this.item, this.onTap});

  @override
  State<ClothingGridTile> createState() => _ClothingGridTileState();
}

class _ClothingGridTileState extends State<ClothingGridTile> {
  String? _signedUrl;
  bool _loadingUrl = true;

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
  }

  Future<void> _loadImageUrl() async {
    if (kDemoMode || widget.item.imagePath == 'demo') {
      setState(() => _loadingUrl = false);
      return;
    }

    try {
      final path = widget.item.thumbnailPath ?? widget.item.imagePath;
      final url = await Supabase.instance.client.storage
          .from(AppConstants.wardrobeBucket)
          .createSignedUrl(path, 3600);
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _loadingUrl = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUrl = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
                widget.item.name ?? widget.item.category.label,
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
    // Demo mode or loading
    if (kDemoMode || widget.item.imagePath == 'demo') {
      return _colorPlaceholder();
    }

    if (_loadingUrl) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_signedUrl == null) {
      return _colorPlaceholder();
    }

    if (kIsWeb) {
      return Image.network(
        _signedUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Colors.grey.shade100,
            child: const Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _colorPlaceholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: _signedUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (_, __) => Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _colorPlaceholder(),
    );
  }

  Widget _colorPlaceholder() {
    return Container(
      width: double.infinity,
      color: _colorFromName(widget.item.color),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.item.category.icon,
              size: 28,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 4),
            Text(
              widget.item.color ?? '',
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
      'pink' => Colors.pink.shade300,
      'orange' => Colors.orange.shade400,
      'yellow' => Colors.yellow.shade600,
      'purple' => Colors.purple.shade400,
      _ => AppTheme.primary.withValues(alpha: 0.6),
    };
  }
}
