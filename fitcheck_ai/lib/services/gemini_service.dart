import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

class GeminiService {
  Future<FitCheckResult> scoreFitCheck(Uint8List outfitImage) async {
    final base64Image = base64Encode(outfitImage);

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${AppConstants.geminiModel}:generateContent?key=${AppConstants.geminiApiKey}',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': '''You are a fashion expert. Rate this outfit on a scale of 1-100 and provide brief feedback.

Consider:
- Color harmony and coordination
- Style cohesion (do the pieces match in formality/vibe?)
- Overall visual appeal
- Versatility

Respond with ONLY valid JSON:
{"score": <number 1-100>, "feedback": "<2-3 sentences of constructive feedback>"}''',
              },
              {
                'inline_data': {
                  'mime_type': 'image/png',
                  'data': base64Image,
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 256,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(response.body);
    final text = body['candidates'][0]['content']['parts'][0]['text'] as String;

    final jsonStr = _extractJson(text);
    final result = jsonDecode(jsonStr) as Map<String, dynamic>;

    return FitCheckResult(
      score: (result['score'] as num).toInt(),
      feedback: result['feedback'] as String,
    );
  }

  String _extractJson(String text) {
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (codeBlockMatch != null) return codeBlockMatch.group(1)!.trim();

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1) return text.substring(start, end + 1);

    return text;
  }
}

class FitCheckResult {
  final int score;
  final String feedback;

  const FitCheckResult({required this.score, required this.feedback});
}
