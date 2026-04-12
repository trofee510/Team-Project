import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/outfit.dart';
import '../../services/claude_service.dart';
import '../../services/supabase_service.dart';
import '../wardrobe/wardrobe_controller.dart';

final outfitControllerProvider =
    AsyncNotifierProvider<OutfitController, void>(OutfitController.new);

class OutfitController extends AsyncNotifier<void> {
  late SupabaseService _supabase;
  late ClaudeService _claude;

  @override
  FutureOr<void> build() {
    _supabase = ref.read(supabaseServiceProvider);
    _claude = ref.read(claudeServiceProvider);
  }

  Future<Outfit> generateOutfit(String occasion) async {
    // Get user's wardrobe items
    final wardrobeItems = ref.read(wardrobeControllerProvider).value ?? [];

    if (wardrobeItems.isEmpty) {
      throw Exception('Add some items to your wardrobe first!');
    }

    // Call Claude to generate outfit
    final suggestion = await _claude.generateOutfit(
      wardrobeItems: wardrobeItems,
      occasion: occasion,
    );

    // Save outfit to database
    final outfitId = const Uuid().v4();
    final outfitData = {
      'id': outfitId,
      'user_id': _supabase.userId,
      'occasion': occasion,
      'reasoning': suggestion.reasoning,
    };

    final outfitItems = suggestion.itemSlots
        .map((slot) => {
              'id': const Uuid().v4(),
              'wardrobe_item_id': slot.itemId,
              'slot': slot.slot,
            })
        .toList();

    final outfit = await _supabase.createOutfit(outfitData, outfitItems);
    return outfit;
  }
}
