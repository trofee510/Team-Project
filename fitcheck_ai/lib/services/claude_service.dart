import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/wardrobe_item.dart';

final claudeServiceProvider = Provider<ClaudeService>((ref) {
  return ClaudeService();
});

class ClaudeService {
  Future<OutfitSuggestion> generateOutfit({
    required List<WardrobeItem> wardrobeItems,
    required String occasion,
    String? weather,
  }) async {
    final itemsList = wardrobeItems.map((item) => {
      'id': item.id,
      'category': item.category.name,
      'subcategory': item.subcategory ?? 'unknown',
      'color': item.color ?? 'unknown',
      'name': item.name ?? '${item.color ?? ''} ${item.subcategory ?? item.category.label}'.trim(),
    }).toList();

    final prompt = '''You are an expert fashion stylist. Given a user's wardrobe items, suggest one complete outfit for the occasion: "$occasion".
${weather != null ? 'Current weather: $weather' : ''}

Wardrobe items (JSON):
${jsonEncode(itemsList)}

Rules:
- Pick exactly one item per slot needed (top, bottom, shoes). Outerwear and accessories are optional.
- Consider color harmony, style cohesion, and occasion appropriateness.
- Only use item IDs from the provided list.

Respond with ONLY valid JSON in this exact format:
{
  "items": [
    {"id": "item-uuid", "slot": "top"},
    {"id": "item-uuid", "slot": "bottom"},
    {"id": "item-uuid", "slot": "shoes"}
  ],
  "reasoning": "2-3 sentences explaining why these items work together."
}''';

    final response = await http.post(
      Uri.parse(AppConstants.claudeApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.claudeApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': AppConstants.claudeModel,
        'max_tokens': 1024,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(response.body);
    final text = body['content'][0]['text'] as String;

    // Extract JSON from response (handles markdown code blocks)
    final jsonStr = _extractJson(text);
    final result = jsonDecode(jsonStr) as Map<String, dynamic>;

    return OutfitSuggestion(
      itemSlots: (result['items'] as List)
          .map((e) => ItemSlot(
                itemId: e['id'] as String,
                slot: e['slot'] as String,
              ))
          .toList(),
      reasoning: result['reasoning'] as String,
    );
  }

  String _extractJson(String text) {
    // Try to find JSON in code blocks first
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (codeBlockMatch != null) return codeBlockMatch.group(1)!.trim();

    // Otherwise find the first { ... } block
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1) return text.substring(start, end + 1);

    return text;
  }
}

class OutfitSuggestion {
  final List<ItemSlot> itemSlots;
  final String reasoning;

  const OutfitSuggestion({required this.itemSlots, required this.reasoning});
}

class ItemSlot {
  final String itemId;
  final String slot;

  const ItemSlot({required this.itemId, required this.slot});
}
