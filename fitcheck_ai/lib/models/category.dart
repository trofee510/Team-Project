import 'package:flutter/material.dart';

enum ClothingCategory {
  tops('Tops', Icons.checkroom),
  bottoms('Bottoms', Icons.straighten),
  dresses('Dresses', Icons.dry_cleaning),
  shoes('Shoes', Icons.ice_skating),
  outerwear('Outerwear', Icons.umbrella),
  accessories('Accessories', Icons.watch),
  bags('Bags', Icons.shopping_bag);

  const ClothingCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  static ClothingCategory fromString(String value) {
    return ClothingCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => ClothingCategory.accessories,
    );
  }
}
