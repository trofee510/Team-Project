import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/extensions.dart';
import '../../main.dart';
import '../../models/category.dart';
import '../../models/wardrobe_item.dart';
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
  bool _isDetecting = false;
  bool _detected = false;

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
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.memory(_imageBytes!,
                                fit: BoxFit.cover),
                          ),
                          if (_isDetecting)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                        color: Colors.white),
                                    SizedBox(height: 12),
                                    Text('Detecting item...',
                                        style: TextStyle(color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          if (_detected)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C853),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, size: 14,
                                        color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('AI Detected',
                                        style: TextStyle(fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 48,
                              color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text('Tap to add a photo',
                              style: TextStyle(color: AppTheme.textSecondary,
                                  fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('AI will auto-detect the item type',
                              style: TextStyle(color: AppTheme.textSecondary
                                  .withValues(alpha: 0.6), fontSize: 13)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Category (auto-detected but editable)
            Row(
              children: [
                Text('Category', style: Theme.of(context).textTheme.titleMedium),
                if (_detected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('(auto-detected)',
                        style: TextStyle(fontSize: 12,
                            color: const Color(0xFF00C853))),
                  ),
              ],
            ),
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

            // Color (auto-detected but editable)
            TextField(
              decoration: InputDecoration(
                labelText: _detected ? 'Color (auto-detected)' : 'Color (optional)',
                hintText: 'e.g. Navy Blue',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              controller: TextEditingController(text: _color ?? ''),
              onChanged: (v) => _color = v.isEmpty ? null : v,
            ),

            const SizedBox(height: 16),

            // Name (auto-detected but editable)
            TextField(
              decoration: InputDecoration(
                labelText: _detected ? 'Name (auto-detected)' : 'Name (optional)',
                hintText: 'e.g. My favorite denim jacket',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              controller: TextEditingController(text: _name ?? ''),
              onChanged: (v) => _name = v.isEmpty ? null : v,
            ),

            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: _imageBytes != null && !_isUploading && !_isDetecting
                  ? _saveItem : null,
              child: _isUploading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save to Wardrobe'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final imageService = ref.read(imageServiceProvider);

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
      setState(() {
        _imageBytes = bytes;
        _detected = false;
      });
      _autoDetect(bytes);
    }
  }

  Future<void> _autoDetect(Uint8List bytes) async {
    // Check for OpenAI key
    bool hasKey;
    try {
      final key = AppConstants.openaiApiKey;
      hasKey = key.isNotEmpty && !key.contains('placeholder') && !key.contains('demo');
    } catch (_) {
      hasKey = false;
    }

    if (!hasKey) return; // skip detection without key

    setState(() => _isDetecting = true);

    try {
      final b64 = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(AppConstants.openaiApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.openaiApiKey}',
        },
        body: jsonEncode({
          'model': AppConstants.openaiModel,
          'max_tokens': 256,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$b64'},
                },
                {
                  'type': 'text',
                  'text': '''Identify this clothing item. Respond with ONLY valid JSON:
{
  "category": "<one of: tops, bottoms, dresses, shoes, outerwear, accessories, bags>",
  "color": "<primary color name, e.g. Navy Blue, Black, White>",
  "name": "<short descriptive name, e.g. Denim Jacket, White Sneakers, Black Jeans>"
}'''
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body);
      final text = body['choices'][0]['message']['content'] as String;

      String jsonStr = text;
      final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
      if (codeBlock != null) {
        jsonStr = codeBlock.group(1)!.trim();
      } else {
        final s = text.indexOf('{');
        final e = text.lastIndexOf('}');
        if (s != -1 && e != -1) jsonStr = text.substring(s, e + 1);
      }

      final r = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _category = ClothingCategory.fromString(r['category'] as String);
          _color = r['color'] as String?;
          _name = r['name'] as String?;
          _detected = true;
        });
      }
    } catch (_) {
      // Detection failed silently — user can still pick manually
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  Future<void> _saveItem() async {
    if (_imageBytes == null) return;

    if (kDemoMode) {
      // Demo mode: add to local state only
      final itemId = const Uuid().v4();
      final item = WardrobeItem(
        id: itemId,
        userId: 'demo',
        category: _category,
        color: _color,
        imagePath: 'demo',
        name: _name ?? _category.label,
        createdAt: DateTime.now(),
      );

      // Add to wardrobe controller's mock list
      final current = ref.read(wardrobeControllerProvider).value ?? [];
      ref.read(wardrobeControllerProvider.notifier).state =
          AsyncData([item, ...current]);

      if (mounted) {
        context.showSnackBar('Item added to wardrobe!');
        context.pop();
      }
      return;
    }

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

      final compressed = imageService.compressImage(_imageBytes!, maxSize: 512);
      final thumbnail = imageService.createThumbnail(_imageBytes!, size: 200);

      final imagePath = '$userId/$itemId.png';
      final thumbPath = '$userId/${itemId}_thumb.png';

      await supabase.uploadImage(imagePath, compressed);
      await supabase.uploadImage(thumbPath, thumbnail);

      await supabase.addWardrobeItem({
        'id': itemId,
        'user_id': userId,
        'category': _category.name,
        'color': _color,
        'image_path': imagePath,
        'thumbnail_path': thumbPath,
        'name': _name,
      });

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
