import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class AppConstants {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;
  static String get claudeApiKey => dotenv.env['CLAUDE_API_KEY']!;
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY']!;

  static const String wardrobeBucket = 'wardrobe-images';
  static const String claudeModel = 'claude-sonnet-4-20250514';
  static const String claudeApiUrl = 'https://api.anthropic.com/v1/messages';
  static const String geminiModel = 'gemini-2.5-flash';

  // Free tier limits
  static const int freeWardrobeLimit = 20;
  static const int freeDailyOutfits = 3;
  static const int freeDailyFitChecks = 3;
}
