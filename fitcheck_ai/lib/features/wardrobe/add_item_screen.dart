import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../core/extensions.dart';
import '../../models/category.dart';
import '../../services/supabase_service.dart';
import '../../services/image_service.dart';
import '../../services/usage_tracker.dart';
import 'wardrobe_controller.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  Uint8List? _imageBytes;
  ClothingCategory _category = ClothingCategory.tops;
  String? _color;
  String? _name;
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview / capture
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 48, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to add a photo',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Category selector
            Text('Category', style: context.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ClothingCategory.values.map((cat) {
                final isSelected = _category == cat;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon, size: 16),
                      const SizedBox(width: 4),
                      Text(cat.label),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Color input
            TextField(
              decoration: InputDecoration(
                labelText: 'Color (optional)',
                hintText: 'e.g. Navy Blue',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => _color = v.isEmpty ? null : v,
            ),

            const SizedBox(height: 16),

            // Name input
            TextField(
              decoration: InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'e.g. My favorite denim jacket',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => _name = v.isEmpty ? null : v,
            ),

            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: _imageBytes != null && !_isUploading ? _saveItem : null,
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save to Wardrobe'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final imageService = ref.read(imageServiceProvider);

    // Show bottom sheet to choose source
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final bytes = source == 'camera'
        ? await imageService.pickFromCamera()
        : await imageService.pickFromGallery();

    if (bytes != null) {
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _saveItem() async {
    if (_imageBytes == null) return;

    final tracker = ref.read(usageTrackerProvider.notifier);
    if (!tracker.canAddItem()) {
      if (mounted) context.push('/paywall');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final imageService = ref.read(imageServiceProvider);
      final itemId = const Uuid().v4();
      final userId = supabase.userId;

      // Compress images
      final compressed = imageService.compressImage(_imageBytes!, maxSize: 512);
      final thumbnail = imageService.createThumbnail(_imageBytes!, size: 200);

      // Upload to storage
      final imagePath = '$userId/$itemId.png';
      final thumbPath = '$userId/${itemId}_thumb.png';

      await supabase.uploadImage(imagePath, compressed);
      await supabase.uploadImage(thumbPath, thumbnail);

      // Save to database
      await supabase.addWardrobeItem({
        'id': itemId,
        'user_id': userId,
        'category': _category.name,
        'color': _color,
        'image_path': imagePath,
        'thumbnail_path': thumbPath,
        'name': _name,
      });

      // Track usage and refresh wardrobe
      tracker.recordItemAdded();
      ref.invalidate(wardrobeControllerProvider);

      if (mounted) {
        context.showSnackBar('Item added to wardrobe!');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to save item: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
