import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// Renders an image stored in Supabase, transparently handling:
///   - paths in grwm-public (battles/*, fitchecks/*) → CDN URL
///   - paths in grwm-private (everything else) → signed URL (1h TTL, cached)
///
/// Pre-resolved URLs are cached per path for the life of the app so the
/// wardrobe grid doesn't hammer Storage on every scroll.
class SupabaseImage extends ConsumerStatefulWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const SupabaseImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  ConsumerState<SupabaseImage> createState() => _SupabaseImageState();
}

class _SupabaseImageState extends ConsumerState<SupabaseImage> {
  static final Map<String, _CachedUrl> _cache = {};

  Future<String>? _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = _resolve();
  }

  @override
  void didUpdateWidget(covariant SupabaseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _urlFuture = _resolve();
    }
  }

  Future<String> _resolve() async {
    final supabase = ref.read(supabaseServiceProvider);

    // Public-bucket paths short-circuit to the CDN.
    final firstSegment = widget.path.split('/').first;
    if (firstSegment == 'battles' || firstSegment == 'fitchecks') {
      return supabase.getPublicCdnUrl(widget.path);
    }

    // Private: reuse in-memory signed URL if still valid (refresh 5min early).
    final cached = _cache[widget.path];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.url;
    }
    final url = await supabase.getSignedUrl(widget.path);
    _cache[widget.path] = _CachedUrl(
      url: url,
      expiresAt: DateTime.now().add(const Duration(minutes: 55)),
    );
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final child = FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return widget.placeholder ??
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey.shade200,
              );
        }
        if (snap.hasError) {
          return widget.errorWidget ??
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
        }
        return CachedNetworkImage(
          imageUrl: snap.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholder: (_, __) =>
              widget.placeholder ?? Container(color: Colors.grey.shade200),
          errorWidget: (_, __, ___) =>
              widget.errorWidget ??
              Container(
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
        );
      },
    );

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;
  const _CachedUrl({required this.url, required this.expiresAt});
}
