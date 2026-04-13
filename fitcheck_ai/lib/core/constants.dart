import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class AppConstants {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;
  static String get openaiApiKey => dotenv.env['OPENAI_API_KEY']!;
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY']!;
  static String get removeBgApiKey => dotenv.env['REMOVEBG_API_KEY']!;
  static const String removeBgApiUrl = 'https://api.remove.bg/v1.0/removebg';

  static const String wardrobeBucket = 'wardrobe-images';
  static const String openaiModel = 'gpt-4o-mini';
  static const String openaiApiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String geminiModel = 'gemini-2.5-flash';

  // Free tier limits
  static const int freeWardrobeLimit = 20;
  static const int freeDailyOutfits = 3;
  static const int freeDailyFitChecks = 3;
}
