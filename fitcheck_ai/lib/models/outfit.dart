import 'wardrobe_item.dart';

class Outfit {
  final String id;
  final String userId;
  final String? occasion;
  final String? reasoning;
  final DateTime createdAt;
  final List<OutfitItem> items;

  const Outfit({
    required this.id,
    required this.userId,
    this.occasion,
    this.reasoning,
    required this.createdAt,
    this.items = const [],
  });

  factory Outfit.fromJson(Map<String, dynamic> json, {List<OutfitItem>? items}) {
    return Outfit(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      occasion: json['occasion'] as String?,
      reasoning: json['reasoning'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: items ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'occasion': occasion,
        'reasoning': reasoning,
      };
}

class OutfitItem {
  final String id;
  final String outfitId;
  final String wardrobeItemId;
  final String slot;
  final WardrobeItem? wardrobeItem;

  const OutfitItem({
    required this.id,
    required this.outfitId,
    required this.wardrobeItemId,
    required this.slot,
    this.wardrobeItem,
  });

  factory OutfitItem.fromJson(Map<String, dynamic> json) {
    return OutfitItem(
      id: json['id'] as String,
      outfitId: json['outfit_id'] as String,
      wardrobeItemId: json['wardrobe_item_id'] as String,
      slot: json['slot'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'outfit_id': outfitId,
        'wardrobe_item_id': wardrobeItemId,
        'slot': slot,
      };
}
