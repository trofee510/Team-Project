import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../core/constants.dart';
import 'ai_proxy_service.dart';
import 'gemini_service.dart' show FullFitResult;
import 'supabase_service.dart';

final fitCheckEngineProvider = Provider<FitCheckEngine>((ref) {
  return FitCheckEngine(
    proxy: ref.watch(aiProxyServiceProvider),
    supabase: ref.watch(supabaseServiceProvider),
  );
});

/// Owns the full fit-check pipeline:
///  1. Normalize + compress the image (resize + JPEG re-encode)
///  2. SHA-256 hash the normalized bytes
///  3. Cache hit? return cached Supabase row
///  4. Else hit the ai-proxy Edge Function (server rate limits + auth + routing)
///  5. Persist to private bucket (personal) OR public bucket (if is_public)
class FitCheckEngine {
  final AiProxyService proxy;
  final SupabaseService supabase;

  static const int _cacheTtlDays = 7;
  // Free-tier input. Pro gets higher resolution so deep-analysis has more detail.
  static const int _freeLongEdge = 800;
  static const int _proLongEdge = 1024;

  FitCheckEngine({required this.proxy, required this.supabase});

  Future<ScoredFit> score(
    Uint8List rawBytes, {
    String? occasion,
    String? aesthetic,
    String? bodyType,
    String? outfitId,
    bool persist = true,
    bool isPublic = false,
    String? challengeId,
    String mode = 'fast',
  }) async {
    // Tier-aware sizing (client-side). Server enforces model choice again.
    final isPro = await _isProSafe();
    final longEdge = isPro ? _proLongEdge : _freeLongEdge;
    final normalized = _normalize(rawBytes, longEdge);
    final hash = sha256.convert(normalized).toString();

    if (persist) {
      final cached = await _lookupCache(hash, normalized);
      if (cached != null) return cached;
    }

    // Fetch profile once for personalization.
    final profile = await _fetchProfileSafe();
    final mergedAesthetic = aesthetic ?? _primaryAesthetic(profile);
    final mergedBodyType = bodyType ?? profile?.bodyType;

    // Hit the proxy — it handles rate limits + model choice + token budget.
    final result = await proxy.scoreFitCheck(
      normalized,
      occasion: occasion,
      aesthetic: mergedAesthetic,
      bodyType: mergedBodyType,
      mode: mode,
    );

    String? imagePath;
    String? fitCheckId;
    if (persist && supabase.currentUser != null) {
      final userId = supabase.userId;
      if (isPublic) {
        imagePath = 'fitchecks/$userId/$hash.jpg';
        await supabase.uploadToPublic(imagePath, normalized);
      } else {
        imagePath = '$userId/fitchecks/$hash.jpg';
        await supabase.uploadImage(imagePath, normalized,
            bucket: AppConstants.privateBucket);
      }

      final inserted = await supabase.client
          .from('fit_checks')
          .insert({
            'user_id': userId,
            'outfit_id': outfitId,
            ...result.toDbFields(),
            'image_path': imagePath,
            'image_hash': hash,
            'is_public': isPublic,
            'challenge_id': challengeId,
          })
          .select()
          .single();
      fitCheckId = inserted['id'] as String;
    }

    return ScoredFit(
      id: fitCheckId,
      hash: hash,
      normalizedBytes: normalized,
      result: result,
      imagePath: imagePath,
      cached: false,
    );
  }

  Future<ScoredFit?> _lookupCache(String hash, Uint8List normalized) async {
    if (supabase.currentUser == null) return null;
    try {
      final cutoff = DateTime.now()
          .subtract(const Duration(days: _cacheTtlDays))
          .toIso8601String();
      final rows = await supabase.client
          .from('fit_checks')
          .select()
          .eq('user_id', supabase.userId)
          .eq('image_hash', hash)
          .gte('created_at', cutoff)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      return ScoredFit(
        id: row['id'] as String,
        hash: hash,
        normalizedBytes: normalized,
        imagePath: row['image_path'] as String?,
        cached: true,
        result: FullFitResult(
          score: (row['score'] as num).toInt(),
          colorHarmony: (row['color_harmony_score'] as num?)?.toInt() ?? 0,
          styleCohesion: (row['style_cohesion_score'] as num?)?.toInt() ?? 0,
          occasionFit: (row['occasion_score'] as num?)?.toInt() ?? 0,
          versatility: (row['fit_score'] as num?)?.toInt() ?? 0,
          feedback: row['feedback'] as String? ?? '',
          tips: ((row['improvement_tips'] as List?) ?? [])
              .map((e) => e.toString())
              .toList(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Uint8List _normalize(Uint8List raw, int maxLongEdge) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return raw;

    final long =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = long > maxLongEdge
        ? img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? maxLongEdge : null,
            height: decoded.height >= decoded.width ? maxLongEdge : null,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    // JPEG q80 is the sweet spot for token count vs. visible quality.
    // WebP would cut ~20% more but the Dart encoder is still experimental.
    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  Future<bool> _isProSafe() async {
    try {
      return await supabase.fetchIsPro();
    } catch (_) {
      return false;
    }
  }

  Future<_Profile?> _fetchProfileSafe() async {
    if (supabase.currentUser == null) return null;
    try {
      final p = await supabase.getMyProfile();
      if (p == null) return null;
      return _Profile(aesthetics: p.aesthetics, bodyType: p.bodyType);
    } catch (_) {
      return null;
    }
  }

  String? _primaryAesthetic(_Profile? p) {
    if (p == null || p.aesthetics.isEmpty) return null;
    return p.aesthetics.take(3).join(', ');
  }
}

class _Profile {
  final List<String> aesthetics;
  final String? bodyType;
  const _Profile({required this.aesthetics, this.bodyType});
}

class ScoredFit {
  final String? id;
  final String hash;
  final Uint8List normalizedBytes;
  final FullFitResult result;
  final String? imagePath;
  final bool cached;

  const ScoredFit({
    required this.id,
    required this.hash,
    required this.normalizedBytes,
    required this.result,
    required this.imagePath,
    required this.cached,
  });
}
