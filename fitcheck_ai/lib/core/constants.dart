import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class AppConstants {
  // Supabase — client-safe.
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;

  // Observability (client-safe DSN / project keys).
  static String get sentryDsn => dotenv.env['SENTRY_DSN'] ?? '';
  static String get posthogKey => dotenv.env['POSTHOG_KEY'] ?? '';
  static String get posthogHost =>
      dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com';

  // RevenueCat public SDK keys (safe to ship in client).
  static String get revenueCatIosKey => dotenv.env['REVENUECAT_IOS_KEY'] ?? '';
  static String get revenueCatAndroidKey =>
      dotenv.env['REVENUECAT_ANDROID_KEY'] ?? '';
  static const String revenueCatEntitlement = 'pro';
  static const String productIdWeekly = 'grwm_pro_weekly';
  static const String productIdAnnual = 'grwm_pro_annual';

  // Storage buckets.
  static const String privateBucket = 'grwm-private';
  static const String publicBucket = 'grwm-public';

  /// Legacy alias. The old single bucket — still returned so existing
  /// feature screens (wardrobe, outfits) that pre-date the split keep
  /// compiling. New code must pick `privateBucket` or `publicBucket`.
  static const String wardrobeBucket = privateBucket;

  // Free-tier limits (also enforced server-side).
  static const int freeWardrobeLimit = 20;
  static const int freeDailyOutfits = 3;
  static const int freeDailyFitChecks = 3;

  // ============================================================
  // DEPRECATED — direct provider keys in the client.
  // New code MUST call ai-proxy (Edge Function). These getters stay
  // only until the remaining legacy call sites migrate:
  //   - features/wardrobe/add_item_screen.dart   (item auto-naming)
  //   - features/my_outfits/my_outfits_screen.dart (outfit gen)
  //   - features/style_my_day/...                 (reads bucket)
  //   - services/background_removal_service.dart
  //   - services/claude_service.dart
  // When all are moved, delete the getters + the env vars.
  // ============================================================
  static String get openaiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static String get claudeApiKey => dotenv.env['CLAUDE_API_KEY'] ?? '';
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String openaiApiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String openaiModel = 'gpt-4o-mini';
  static const String claudeApiUrl = 'https://api.anthropic.com/v1/messages';
  static const String claudeModel = 'claude-sonnet-4-20250514';
  static const String geminiModel = 'gemini-2.5-flash';
}
