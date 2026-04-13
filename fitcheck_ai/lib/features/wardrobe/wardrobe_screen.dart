import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/category.dart';
import '../../models/wardrobe_item.dart';
import '../../widgets/clothing_grid_tile.dart';
import 'wardrobe_controller.dart';
import 'item_detail_screen.dart';

// null = show category selection screen, non-null = show items for that category
final selectedCategoryProvider = StateProvider<ClothingCategory?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedColorProvider = StateProvider<String?>((ref) => null);
final sortModeProvider = StateProvider<String>((ref) => 'newest');

class WardrobeScreen extends ConsumerWidget {
  const WardrobeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);

    // If no category selected, show the category picker landing
    if (selectedCategory == null) {
      return _CategorySelectionView();
    }

    // Otherwise show the items grid for that category
    return _CategoryItemsView(category: selectedCategory);
  }
}

// ─── Category Selection Landing ─────────────────────────────────────────

class _CategorySelectionView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobeAsync = ref.watch(wardrobeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wardrobe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: () => context.push('/wardrobe/add'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Browse by Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a category to view your items',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: wardrobeAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (items) {
                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: ClothingCategory.values.length + 1, // +1 for "View All"
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // "View All" tile
                        final totalCount = items.length;
                        return _CategoryTile(
                          icon: Icons.grid_view_rounded,
                          label: 'View All',
                          count: totalCount,
                          color: AppTheme.primary,
                          onTap: () => _enterAllItems(ref),
                        );
                      }

                      final cat = ClothingCategory.values[index - 1];
                      final count = items.where((i) => i.category == cat).length;
                      return _CategoryTile(
                        icon: cat.icon,
                        label: cat.label,
                        count: count,
                        color: _categoryColor(index - 1),
                        onTap: () => ref.read(selectedCategoryProvider.notifier).state = cat,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'wardrobe_fab',
        onPressed: () => context.push('/wardrobe/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Use a sentinel value — we set a special provider to flag "view all" mode
  void _enterAllItems(WidgetRef ref) {
    // Set to the first category then immediately use the "all" view
    // We'll use `tops` as a dummy — the items view checks _viewAllMode
    ref.read(_viewAllModeProvider.notifier).state = true;
    ref.read(selectedCategoryProvider.notifier).state = ClothingCategory.tops;
  }

  Color _categoryColor(int index) {
    const colors = [
      Color(0xFF6C5CE7), // purple
      Color(0xFF00B894), // green
      Color(0xFFE17055), // coral
      Color(0xFF0984E3), // blue
      Color(0xFFFDAA5E), // orange
      Color(0xFFE84393), // pink
      Color(0xFF00CEC9), // teal
      Color(0xFF636E72), // grey
      Color(0xFFA29BFE), // lavender
      Color(0xFF55EFC4), // mint
      Color(0xFFFF7675), // salmon
      Color(0xFF74B9FF), // sky
      Color(0xFFDFE6E9), // silver
    ];
    return colors[index % colors.length];
  }
}

// Provider to track "view all" mode vs single-category mode
final _viewAllModeProvider = StateProvider<bool>((ref) => false);

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count items',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category Items View ────────────────────────────────────────────────

class _CategoryItemsView extends ConsumerWidget {
  final ClothingCategory category;
  const _CategoryItemsView({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobeAsync = ref.watch(wardrobeControllerProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedColor = ref.watch(selectedColorProvider);
    final sortMode = ref.watch(sortModeProvider);
    final viewAll = ref.watch(_viewAllModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(selectedCategoryProvider.notifier).state = null;
            ref.read(_viewAllModeProvider.notifier).state = false;
            ref.read(selectedColorProvider.notifier).state = null;
            ref.read(searchQueryProvider.notifier).state = '';
          },
        ),
        title: const Text('My Wardrobe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: () => context.push('/wardrobe/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter row: Category popup, Color popup, Sort
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                // Category popup button
                _CategoryPopupButton(
                  category: viewAll ? null : category,
                  viewAll: viewAll,
                ),
                const SizedBox(width: 8),
                // Color popup button
                _ColorPopupButton(selectedColor: selectedColor),
                const Spacer(),
                // Sort popup
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, size: 20),
                  tooltip: 'Sort by',
                  onSelected: (val) => ref.read(sortModeProvider.notifier).state = val,
                  itemBuilder: (_) => [
                    _sortItem('newest', 'Newest First', sortMode),
                    _sortItem('oldest', 'Oldest First', sortMode),
                    _sortItem('name', 'Name A-Z', sortMode),
                    _sortItem('most_worn', 'Most Worn', sortMode),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Item count + clear filters
          wardrobeAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) {
              final filtered = _filterItems(items, viewAll ? null : category, searchQuery, selectedColor, sortMode);
              final hasActiveFilters = selectedColor != null || searchQuery.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} items',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          ref.read(selectedColorProvider.notifier).state = null;
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Clear filters',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Items grid
          Expanded(
            child: wardrobeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                final filtered = _filterItems(items, viewAll ? null : category, searchQuery, selectedColor, sortMode);

                if (filtered.isEmpty) {
                  return _EmptyState(
                    hasItems: items.isNotEmpty,
                    isSearching: searchQuery.isNotEmpty || selectedColor != null,
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ClothingGridTile(
                      item: item,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ItemDetailScreen(item: item),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'wardrobe_fab',
        onPressed: () => context.push('/wardrobe/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label, String current) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (current == value)
            Icon(Icons.check, size: 16, color: AppTheme.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  List<WardrobeItem> _filterItems(
    List<WardrobeItem> items,
    ClothingCategory? category,
    String query,
    String? color,
    String sortMode,
  ) {
    var filtered = items;

    if (category != null) {
      filtered = filtered.where((i) => i.category == category).toList();
    }

    if (color != null) {
      final c = color.toLowerCase();
      filtered = filtered.where((i) =>
          i.color?.toLowerCase().contains(c) ?? false).toList();
    }

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered.where((i) {
        return (i.name?.toLowerCase().contains(q) ?? false) ||
            (i.color?.toLowerCase().contains(q) ?? false) ||
            (i.subcategory?.toLowerCase().contains(q) ?? false) ||
            i.category.label.toLowerCase().contains(q) ||
            (i.brand?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    switch (sortMode) {
      case 'oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'name':
        filtered.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      case 'most_worn':
        filtered.sort((a, b) => b.wearCount.compareTo(a.wearCount));
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return filtered;
  }
}

// ─── Color Popup Button ─────────────────────────────────────────────────

class _ColorPopupButton extends ConsumerWidget {
  final String? selectedColor;
  const _ColorPopupButton({required this.selectedColor});

  static const _colors = [
    (null, 'All Colors', Colors.grey),
    ('black', 'Black', Colors.black),
    ('white', 'White', Color(0xFFE0E0E0)),
    ('blue', 'Blue', Colors.blue),
    ('red', 'Red', Colors.red),
    ('green', 'Green', Colors.green),
    ('pink', 'Pink', Colors.pink),
    ('brown', 'Brown', Colors.brown),
    ('grey', 'Grey', Colors.blueGrey),
    ('navy', 'Navy', Color(0xFF1A237E)),
    ('beige', 'Beige', Color(0xFFD4A373)),
    ('orange', 'Orange', Colors.orange),
    ('yellow', 'Yellow', Color(0xFFF9A825)),
    ('purple', 'Purple', Colors.purple),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasColor = selectedColor != null;

    return GestureDetector(
      onTap: () => _showColorPicker(context, ref),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: hasColor ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasColor ? AppTheme.primary.withValues(alpha: 0.4) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasColor) ...[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _swatchColor(selectedColor),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 0.5),
                ),
              ),
              const SizedBox(width: 6),
            ] else ...[
              Icon(Icons.palette_outlined, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              hasColor ? selectedColor! : 'Color',
              style: TextStyle(
                fontSize: 13,
                color: hasColor ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: hasColor ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16,
              color: hasColor ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Filter by Color',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _colors.map((c) {
                  final (value, label, swatch) = c;
                  final isSelected = selectedColor == value;
                  return GestureDetector(
                    onTap: () {
                      ref.read(selectedColorProvider.notifier).state = value;
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? Border.all(color: AppTheme.primary, width: 1.5)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: swatch,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _swatchColor(String? name) {
    for (final c in _colors) {
      if (c.$1 == name) return c.$3;
    }
    return Colors.grey;
  }
}

// ─── Shared Widgets ─────────────────────────────────────────────────────

class _CategoryPopupButton extends ConsumerWidget {
  final ClothingCategory? category;
  final bool viewAll;

  const _CategoryPopupButton({required this.category, required this.viewAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = viewAll ? 'All Items' : category?.label ?? 'Category';
    final icon = viewAll ? Icons.grid_view_rounded : (category?.icon ?? Icons.checkroom);

    return GestureDetector(
      onTap: () => _showCategoryPicker(context, ref),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // "All Items" option
                  _buildChip(
                    ctx: ctx,
                    ref: ref,
                    icon: Icons.grid_view_rounded,
                    label: 'All Items',
                    isSelected: viewAll,
                    onTap: () {
                      ref.read(_viewAllModeProvider.notifier).state = true;
                      Navigator.pop(ctx);
                    },
                  ),
                  // Each category
                  ...ClothingCategory.values.map(
                    (cat) => _buildChip(
                      ctx: ctx,
                      ref: ref,
                      icon: cat.icon,
                      label: cat.label,
                      isSelected: !viewAll && category == cat,
                      onTap: () {
                        ref.read(_viewAllModeProvider.notifier).state = false;
                        ref.read(selectedCategoryProvider.notifier).state = cat;
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required BuildContext ctx,
    required WidgetRef ref,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppTheme.primary, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasItems;
  final bool isSearching;

  const _EmptyState({required this.hasItems, required this.isSearching});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.checkroom,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? 'No items match your search'
                : 'No items in this category yet',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!hasItems && !isSearching) ...[
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first item!',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
