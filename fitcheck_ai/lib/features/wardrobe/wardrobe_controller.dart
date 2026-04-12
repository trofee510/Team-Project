import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../models/category.dart';
import '../../models/wardrobe_item.dart';
import '../../services/supabase_service.dart';

final wardrobeControllerProvider =
    AsyncNotifierProvider<WardrobeController, List<WardrobeItem>>(
        WardrobeController.new);

class WardrobeController extends AsyncNotifier<List<WardrobeItem>> {
  @override
  FutureOr<List<WardrobeItem>> build() async {
    if (kDemoMode) return _mockItems;

    final supabase = ref.read(supabaseServiceProvider);
    return supabase.getWardrobeItems();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    if (kDemoMode) {
      state = AsyncData(_mockItems);
      return;
    }
    final supabase = ref.read(supabaseServiceProvider);
    state = await AsyncValue.guard(() => supabase.getWardrobeItems());
  }

  Future<void> deleteItem(WardrobeItem item) async {
    if (kDemoMode) {
      state = AsyncData(
        state.value?.where((i) => i.id != item.id).toList() ?? [],
      );
      return;
    }
    final supabase = ref.read(supabaseServiceProvider);
    await supabase.deleteImage(item.imagePath);
    if (item.thumbnailPath != null) {
      await supabase.deleteImage(item.thumbnailPath!);
    }
    await supabase.deleteWardrobeItem(item.id);
    state = AsyncData(
      state.value?.where((i) => i.id != item.id).toList() ?? [],
    );
  }
}

// Mock data for UI preview
final _mockItems = [
  WardrobeItem(
    id: '1', userId: 'demo', category: ClothingCategory.tops,
    subcategory: 'T-Shirt', color: 'White',
    imagePath: 'demo', name: 'White Tee',
    createdAt: DateTime.now(),
  ),
  WardrobeItem(
    id: '2', userId: 'demo', category: ClothingCategory.tops,
    subcategory: 'Button-Down', color: 'Light Blue',
    imagePath: 'demo', name: 'Oxford Shirt',
    createdAt: DateTime.now(),
  ),
  WardrobeItem(
    id: '3', userId: 'demo', category: ClothingCategory.bottoms,
    subcategory: 'Jeans', color: 'Dark Blue',
    imagePath: 'demo', name: 'Slim Jeans',
    createdAt: DateTime.now(),
  ),
  WardrobeItem(
    id: '4', userId: 'demo', category: ClothingCategory.bottoms,
    subcategory: 'Chinos', color: 'Khaki',
    imagePath: 'demo', name: 'Khaki Chinos',
    createdAt: DateTime.now(),
  ),
  WardrobeItem(
    id: '5', userId: 'demo', category: ClothingCategory.shoes,
    subcategory: 'Sneakers', color: 'White',
    imagePath: 'demo', name: 'White Sneakers',
    createdAt: DateTime.now(),
  ),
  WardrobeItem(
    id: '6', userId: 'demo', category: ClothingCategory.shoes,
    subcategory: 'Boots', color: 'Brown',
    imagePath: 'demo', name: 'Chelsea Boots',
    createdAt: DateTime.now(),
  ),
  WardrobeItem(
    id: '7', userId: 'demo', category: ClothingCategory.outerwear,
    subcategory: 'Jacket', color: 'Black',
    imagePath: 'demo', name: 'Bomber Jacket',
    createdAt: DateTime.now(),
  ),
  WardrobeItem(
    id: '8', userId: 'demo', category: ClothingCategory.accessories,
    subcategory: 'Watch', color: 'Silver',
    imagePath: 'demo', name: 'Silver Watch',
    createdAt: DateTime.now(),
  ),
];
