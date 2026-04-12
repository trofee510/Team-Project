import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../main.dart';
import '../../models/outfit.dart';
import '../../services/supabase_service.dart';
import 'generate_sheet.dart';

final outfitHistoryProvider = FutureProvider<List<Outfit>>((ref) {
  if (kDemoMode) {
    return [
      Outfit(
        id: 'demo-1', userId: 'demo', occasion: 'casual',
        reasoning: 'The white tee pairs perfectly with slim jeans for an effortless casual look. White sneakers keep it clean and cohesive.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Outfit(
        id: 'demo-2', userId: 'demo', occasion: 'date_night',
        reasoning: 'The Oxford shirt with chinos creates a smart-casual vibe. Chelsea boots elevate the look for a date night.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
  final supabase = ref.read(supabaseServiceProvider);
  return supabase.getOutfits();
});

class OutfitHistoryScreen extends ConsumerWidget {
  const OutfitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfitsAsync = ref.watch(outfitHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Outfits')),
      body: outfitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (outfits) {
          if (outfits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 64,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No outfits yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate your first AI-styled outfit!',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: outfits.length,
            itemBuilder: (context, index) {
              final outfit = outfits[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.style, color: AppTheme.primary),
                  ),
                  title: Text(
                    outfit.occasion?.toUpperCase() ?? 'OUTFIT',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    outfit.reasoning ?? 'Tap to view',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/outfit/${outfit.id}'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'generate_fab',
        onPressed: () => _showGenerateSheet(context),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate'),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showGenerateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const GenerateSheet(),
    );
  }
}
