import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'gemini_service.dart' show FullFitResult;
import 'supabase_service.dart';

final aiProxyServiceProvider = Provider<AiProxyService>((ref) {
  return AiProxyService(ref.watch(supabaseServiceProvider));
});

/// Thrown when the server says the user hit today's free-tier limit.
/// Caller should route to /paywall?reason=limit.
class FitCheckLimitReached implements Exception {
  final String tier;
  FitCheckLimitReached(this.tier);
  @override
  String toString() => 'FitCheckLimitReached(tier=$tier)';
}

/// Single entry point for every AI call. Talks only to the Supabase
/// Edge Function `ai-proxy`. No provider API keys live in the app.
class AiProxyService {
  final SupabaseService _supabase;

  AiProxyService(this._supabase);

  Future<FullFitResult> scoreFitCheck(
    Uint8List jpegBytes, {
    String? occasion,
    String? aesthetic,
    String? bodyType,
    String mode = 'fast',
  }) async {
    final session = _supabase.client.auth.currentSession;
    if (session == null) {
      throw Exception('Not signed in');
    }

    final url = Uri.parse('${AppConstants.supabaseUrl}/functions/v1/ai-proxy');
    final resp = await http.post(
      url,
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer ${session.accessToken}',
        'apikey': AppConstants.supabaseAnonKey,
      },
      body: jsonEncode({
        'task': 'fit_check',
        'mode': mode,
        'image_base64': base64Encode(jpegBytes),
        'context': {
          if (occasion != null && occasion.isNotEmpty) 'occasion': occasion,
          if (aesthetic != null && aesthetic.isNotEmpty) 'aesthetic': aesthetic,
          if (bodyType != null && bodyType.isNotEmpty) 'body_type': bodyType,
        },
      }),
    );

    if (resp.statusCode == 402) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {}
      throw FitCheckLimitReached(body?['tier'] as String? ?? 'free');
    }
    if (resp.statusCode != 200) {
      throw Exception('ai-proxy ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    int clamp(dynamic v) => ((v as num?)?.toInt() ?? 0).clamp(0, 100);
    final tips = (data['tips'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList() ??
        const [];
    return FullFitResult(
      score: clamp(data['score']),
      colorHarmony: clamp(data['color_harmony']),
      styleCohesion: clamp(data['style_cohesion']),
      occasionFit: clamp(data['occasion_fit']),
      versatility: clamp(data['versatility']),
      feedback: (data['feedback'] as String?)?.trim() ?? '',
      tips: tips,
    );
  }
}
