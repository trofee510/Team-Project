import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_service.dart';

final featureFlagsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final supabase = ref.watch(supabaseServiceProvider);
  try {
    final rows = await supabase.client.from('feature_flags').select('key, enabled');
    return {
      for (final r in rows as List) r['key'] as String: r['enabled'] == true,
    };
  } catch (_) {
    return const {};
  }
});

/// Helpers for specific flags — prefer these over string keys at call sites.
extension FeatureFlagsX on Map<String, bool> {
  bool get killAiProxy => this['kill_ai_proxy'] ?? false;
  bool get strangerFeedEnabled => this['enable_stranger_feed'] ?? true;
}
