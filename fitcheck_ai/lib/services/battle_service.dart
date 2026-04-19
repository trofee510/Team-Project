import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fit_battle.dart';
import 'supabase_service.dart';

final battleServiceProvider = Provider<BattleService>((ref) {
  return BattleService(ref.watch(supabaseServiceProvider));
});

class BattleService {
  final SupabaseService _supabase;
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
  static const _codeLength = 6;
  static const _defaultTtl = Duration(hours: 48);

  BattleService(this._supabase);

  /// Creates a battle, uploads the photo, and returns the battle + shareable URL.
  Future<FitBattle> create({
    required Uint8List imageBytes,
    String? caption,
    String? displayName,
    int? aiScore,
    String? aiFeedback,
  }) async {
    final userId = _supabase.userId;
    final code = _generateCode();
    // Battles live in the public bucket so deep-linked friends can load
    // images from the CDN without needing a signed URL.
    final imagePath = 'battles/$userId/$code.jpg';
    await _supabase.uploadToPublic(imagePath, imageBytes);

    final expiresAt = DateTime.now().toUtc().add(_defaultTtl);
    final inserted = await _supabase.client
        .from('fit_battles')
        .insert({
          'user_id': userId,
          'code': code,
          'owner_display_name': displayName,
          'image_path': imagePath,
          'caption': caption,
          'ai_score': aiScore,
          'ai_feedback': aiFeedback,
          'expires_at': expiresAt.toIso8601String(),
        })
        .select()
        .single();
    return FitBattle.fromJson(inserted);
  }

  Future<BattleSummary?> getByCode(String code) async {
    final battleRow = await _supabase.client
        .from('fit_battles')
        .select()
        .eq('code', code.toUpperCase())
        .maybeSingle();
    if (battleRow == null) return null;
    final battle = FitBattle.fromJson(battleRow);
    final ratings = await _listRatings(battle.id);
    return BattleSummary(battle: battle, ratings: ratings);
  }

  Future<List<FitBattle>> myBattles() async {
    final rows = await _supabase.client
        .from('fit_battles')
        .select()
        .eq('user_id', _supabase.userId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map((r) => FitBattle.fromJson(r)).toList();
  }

  Future<List<BattleRating>> _listRatings(String battleId) async {
    final rows = await _supabase.client
        .from('fit_battle_ratings')
        .select()
        .eq('battle_id', battleId)
        .order('created_at', ascending: false);
    return rows.map((r) => BattleRating.fromJson(r)).toList();
  }

  Future<BattleRating> rate({
    required String battleId,
    required int score,
    required String raterName,
    String? comment,
  }) async {
    final raterId = _supabase.currentUser?.id;
    final payload = {
      'battle_id': battleId,
      'rater_id': raterId,
      'rater_name': raterName.trim().isEmpty ? 'Friend' : raterName.trim(),
      'score': score.clamp(1, 100),
      'comment': comment?.trim().isEmpty ?? true ? null : comment!.trim(),
    };

    // Upsert so a friend editing their rating doesn't create duplicates.
    final inserted = await _supabase.client
        .from('fit_battle_ratings')
        .upsert(payload, onConflict: 'battle_id,rater_id')
        .select()
        .single();
    return BattleRating.fromJson(inserted);
  }

  String shareUrl(String code) => 'https://grwm.app/b/$code';

  String _generateCode() {
    final rng = Random.secure();
    return List.generate(
      _codeLength,
      (_) => _alphabet[rng.nextInt(_alphabet.length)],
    ).join();
  }
}
