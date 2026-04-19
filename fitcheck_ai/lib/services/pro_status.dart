import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_service.dart';

/// Server-trusted Pro status. Prefer this over the client-only
/// `usageTrackerProvider.isPro` for any feature gate (share-card watermark,
/// locked sub-scores, model routing hint). Refreshes on signIn + after
/// successful purchase.
final proStatusProvider =
    StateNotifierProvider<ProStatusController, bool>((ref) {
  final controller = ProStatusController(ref.watch(supabaseServiceProvider));
  controller.refresh();
  return controller;
});

class ProStatusController extends StateNotifier<bool> {
  final SupabaseService _supabase;
  ProStatusController(this._supabase) : super(false);

  Future<void> refresh() async {
    try {
      final pro = await _supabase.fetchIsPro();
      if (mounted) state = pro;
    } catch (_) {
      // Best-effort; leave current state.
    }
  }
}
