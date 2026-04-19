import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/extensions.dart';
import '../../core/theme.dart';

/// First launch. One CTA: "Score your fit now".
/// Goal: show AI value in under 30 seconds before asking anything.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _working = false;

  Future<void> _snap(ImageSource src) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final file = await ImagePicker()
          .pickImage(source: src, imageQuality: 90);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      context.push('/instant-fit', extra: bytes);
    } catch (e) {
      if (mounted) context.showSnackBar('Couldn\'t load image: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              const Text(
                'Score your fit in 10 seconds',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.2),
              ),
              const SizedBox(height: 10),
              const Text(
                'AI rates your outfit 1–100 with feedback on color, '
                'style, occasion, and versatility.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.4),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed:
                      _working ? null : () => _snap(ImageSource.camera),
                  icon: _working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.camera_alt),
                  label: const Text('Take a photo',
                      style: TextStyle(fontSize: 17)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed:
                      _working ? null : () => _snap(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose from gallery'),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.go('/auth'),
                child: const Text('I already have an account'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
