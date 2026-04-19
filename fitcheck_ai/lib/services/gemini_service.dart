import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_proxy_service.dart';

/// DEPRECATED: direct Gemini calls are gone. This file exists so existing
/// callers (`geminiServiceProvider`, `FullFitResult`) keep compiling while
/// the migration to [AiProxyService] lands.
///
/// All scoring now goes through the Supabase Edge Function `ai-proxy`,
/// which enforces auth + rate limits + model routing server-side.
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(ref.watch(aiProxyServiceProvider));
});

class GeminiService {
  final AiProxyService _proxy;
  GeminiService(this._proxy);

  Future<FullFitResult> scoreFitCheck(
    Uint8List outfitImage, {
    String? occasion,
    String? aesthetic,
    String? bodyType,
    String? seed, // ignored — server handles determinism
  }) {
    return _proxy.scoreFitCheck(
      outfitImage,
      occasion: occasion,
      aesthetic: aesthetic,
      bodyType: bodyType,
    );
  }
}

class FullFitResult {
  final int score;
  final int colorHarmony;
  final int styleCohesion;
  final int occasionFit;
  final int versatility;
  final String feedback;
  final List<String> tips;

  const FullFitResult({
    required this.score,
    required this.colorHarmony,
    required this.styleCohesion,
    required this.occasionFit,
    required this.versatility,
    required this.feedback,
    required this.tips,
  });

  Map<String, dynamic> toDbFields() => {
        'score': score,
        'feedback': feedback,
        'color_harmony_score': colorHarmony,
        'style_cohesion_score': styleCohesion,
        'occasion_score': occasionFit,
        'fit_score': versatility,
        'improvement_tips': tips,
      };
}
