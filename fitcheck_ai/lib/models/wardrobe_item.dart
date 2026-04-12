import 'category.dart';

class WardrobeItem {
  final String id;
  final String userId;
  final ClothingCategory category;
  final String? subcategory;
  final String? color;
  final String imagePath;
  final String? thumbnailPath;
  final String? name;
  final String? brand;
  final double? purchasePrice;
  final int wearCount;
  final List<String>? tags;
  final String? season;
  final DateTime createdAt;

  const WardrobeItem({
    required this.id,
    required this.userId,
    required this.category,
    this.subcategory,
    this.color,
    required this.imagePath,
    this.thumbnailPath,
    this.name,
    this.brand,
    this.purchasePrice,
    this.wearCount = 0,
    this.tags,
    this.season,
    required this.createdAt,
  });

  double? get costPerWear {
    if (purchasePrice == null || wearCount == 0) return null;
    return purchasePrice! / wearCount;
  }

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: ClothingCategory.fromString(json['category'] as String),
      subcategory: json['subcategory'] as String?,
      color: json['color'] as String?,
      imagePath: json['image_path'] as String,
      thumbnailPath: json['thumbnail_path'] as String?,
      name: json['name'] as String?,
      brand: json['brand'] as String?,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      wearCount: json['wear_count'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      season: json['season'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'category': category.name,
        'subcategory': subcategory,
        'color': color,
        'image_path': imagePath,
        'thumbnail_path': thumbnailPath,
        'name': name,
        'brand': brand,
        'purchase_price': purchasePrice,
        'wear_count': wearCount,
        'tags': tags,
        'season': season,
      };

  WardrobeItem copyWith({
    String? name,
    String? color,
    ClothingCategory? category,
    String? subcategory,
    String? brand,
    double? purchasePrice,
    int? wearCount,
    List<String>? tags,
    String? season,
  }) {
    return WardrobeItem(
      id: id,
      userId: userId,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      color: color ?? this.color,
      imagePath: imagePath,
      thumbnailPath: thumbnailPath,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      wearCount: wearCount ?? this.wearCount,
      tags: tags ?? this.tags,
      season: season ?? this.season,
      createdAt: createdAt,
    );
  }
}
