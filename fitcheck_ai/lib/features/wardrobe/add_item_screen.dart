import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
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
  String? _subcategory;
  String? _brand;
  bool _isUploading = false;
  bool _isAnalyzing = false;

  final _colorController = TextEditingController();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();

  @override
  void dispose() {
    _colorController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

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
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (_isAnalyzing)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: Colors.white),
                                    SizedBox(height: 12),
                                    Text(
                                      'Processing image...',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Tap to change
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.photo_library, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 56, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'Take a photo or browse device',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AI will auto-detect the item details',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Category selector
            Text('Category', style: Theme.of(context).textTheme.titleMedium),
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

            // Color input (pre-filled by AI)
            TextField(
              controller: _colorController,
              decoration: InputDecoration(
                labelText: 'Color',
                hintText: 'e.g. Navy Blue',
                prefixIcon: const Icon(Icons.palette_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _color != null
                    ? Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _colorPreview(_color),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _color = v.isEmpty ? null : v),
            ),

            const SizedBox(height: 16),

            // Name input (pre-filled by AI)
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Slim Fit Oxford Shirt',
                prefixIcon: const Icon(Icons.label_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _name = v.isEmpty ? null : v),
            ),

            const SizedBox(height: 16),

            // Brand input (pre-filled by AI)
            TextField(
              controller: _brandController,
              decoration: InputDecoration(
                labelText: 'Brand',
                hintText: 'e.g. Nike, Zara, Levi\'s',
                prefixIcon: const Icon(Icons.storefront_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _brand = v.isEmpty ? null : v),
            ),

            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: _imageBytes != null && !_isUploading && !_isAnalyzing ? _saveItem : null,
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
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              subtitle: const Text('Use your camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Browse Device'),
              subtitle: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final imageService = ref.read(imageServiceProvider);
    final bytes = source == 'camera'
        ? await imageService.pickFromCamera()
        : await imageService.pickFromGallery();

    if (bytes != null) {
      setState(() {
        _imageBytes = bytes;
        _isAnalyzing = true;
      });

      // Remove background, then run AI categorization
      final cleaned = await _removeBackground(bytes);
      if (cleaned != null && mounted) {
        setState(() => _imageBytes = cleaned);
      }
      await _analyzeWithAI(_imageBytes!);
    }
  }

  Future<Uint8List?> _removeBackground(Uint8List imageBytes) async {
    try {
      final apiKey = AppConstants.removeBgApiKey;
      if (apiKey.isEmpty || apiKey.startsWith('your_')) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConstants.removeBgApiUrl),
      );
      request.headers['X-Api-Key'] = apiKey;
      request.fields['size'] = 'auto';
      request.files.add(http.MultipartFile.fromBytes(
        'image_file',
        imageBytes,
        filename: 'image.jpg',
      ));

      final response = await request.send();
      if (response.statusCode == 200) {
        return await response.stream.toBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _analyzeWithAI(Uint8List imageBytes) async {
    try {
      final apiKey = AppConstants.openaiApiKey;
      if (apiKey.isEmpty || apiKey.startsWith('your_')) {
        setState(() => _isAnalyzing = false);
        return;
      }

      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(AppConstants.openaiApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
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
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
                {
                  'type': 'text',
                  'text': 'Identify this clothing item. Respond with ONLY valid JSON, no markdown:\n{"category": "tops|bottoms|dresses|shoes|outerwear|activewear|swimwear|sleepwear|suits|jewelry|hats|accessories|bags", "color": "the primary color", "name": "short descriptive name like Blue Denim Jacket", "subcategory": "specific type like t-shirt, jeans, sneakers, etc.", "brand": "brand name if visible or recognizable, otherwise null"}'
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final text = body['choices'][0]['message']['content'] as String;

        // Extract JSON
        String jsonStr = text;
        final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
        if (codeBlock != null) {
          jsonStr = codeBlock.group(1)!.trim();
        } else {
          final start = text.indexOf('{');
          final end = text.lastIndexOf('}');
          if (start != -1 && end != -1) jsonStr = text.substring(start, end + 1);
        }

        final result = jsonDecode(jsonStr) as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            _category = ClothingCategory.fromString(result['category'] as String? ?? 'tops');
            _color = result['color'] as String?;
            _name = result['name'] as String?;
            _subcategory = result['subcategory'] as String?;
            _brand = result['brand'] as String?;
            _colorController.text = _color ?? '';
            _nameController.text = _name ?? '';
            _brandController.text = _brand ?? '';
            _isAnalyzing = false;
          });
        }
      } else {
        if (mounted) setState(() => _isAnalyzing = false);
      }
    } catch (e) {
      // AI failed - let user fill manually
      if (mounted) setState(() => _isAnalyzing = false);
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
        'subcategory': _subcategory,
        'color': _color,
        'image_path': imagePath,
        'thumbnail_path': thumbPath,
        'name': _name,
        'brand': _brand,
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

  Color _colorPreview(String? colorName) {
    return switch (colorName?.toLowerCase()) {
      'white' => Colors.white,
      'black' => Colors.black,
      'red' => Colors.red,
      'blue' || 'dark blue' || 'navy' => Colors.blue,
      'light blue' => Colors.lightBlue,
      'green' => Colors.green,
      'yellow' => Colors.yellow,
      'orange' => Colors.orange,
      'pink' => Colors.pink,
      'purple' => Colors.purple,
      'brown' => Colors.brown,
      'grey' || 'gray' => Colors.grey,
      'beige' || 'khaki' => Colors.amber.shade200,
      _ => Colors.grey.shade300,
    };
  }
}
