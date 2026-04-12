import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/extensions.dart';
import '../../services/usage_tracker.dart';
import 'outfit_controller.dart';

class GenerateSheet extends ConsumerStatefulWidget {
  const GenerateSheet({super.key});

  @override
  ConsumerState<GenerateSheet> createState() => _GenerateSheetState();
}

class _GenerateSheetState extends ConsumerState<GenerateSheet> {
  String _occasion = 'casual';
  bool _isGenerating = false;

  static const _occasions = [
    ('casual', 'Casual', Icons.weekend),
    ('work', 'Work', Icons.business_center),
    ('date_night', 'Date Night', Icons.favorite),
    ('formal', 'Formal', Icons.diamond),
    ('workout', 'Workout', Icons.fitness_center),
    ('outdoor', 'Outdoor', Icons.park),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Generate Outfit',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick an occasion and let AI style you',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          // Occasion chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _occasions.map((o) {
              final isSelected = _occasion == o.$1;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(o.$3, size: 16),
                    const SizedBox(width: 4),
                    Text(o.$2),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => setState(() => _occasion = o.$1),
                selectedColor: AppTheme.primary.withValues(alpha: 0.2),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isGenerating ? null : _generate,
            child: _isGenerating
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Styling your outfit...'),
                    ],
                  )
                : const Text('Generate Outfit'),
          ),

          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final remaining = ref.watch(usageTrackerProvider.notifier).remainingOutfitsText;
              return Text(
                remaining,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    final tracker = ref.read(usageTrackerProvider.notifier);
    if (!tracker.canGenerateOutfit()) {
      if (mounted) {
        Navigator.pop(context);
        context.push('/paywall');
      }
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final outfit = await ref
          .read(outfitControllerProvider.notifier)
          .generateOutfit(_occasion);

      tracker.recordOutfitGeneration();

      if (mounted) {
        Navigator.pop(context);
        context.push('/outfit/${outfit.id}');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to generate outfit: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
