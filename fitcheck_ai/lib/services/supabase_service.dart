import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wardrobe_item.dart';
import '../models/outfit.dart';
import '../models/fit_check.dart';
import '../core/constants.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  SupabaseClient get client => _client;
  User? get currentUser => _client.auth.currentUser;
  String get userId => currentUser!.id;

  // ── Auth ──────────────────────────────────────────────
  Future<bool> signInWithApple() =>
      _client.auth.signInWithOAuth(OAuthProvider.apple);

  Future<bool> signInWithGoogle() async {
    final res = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.grwm.app://callback',
    );
    return res;
  }

  Future<void> signOut() => _client.auth.signOut();

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Storage ───────────────────────────────────────────
  Future<String> uploadImage(String path, Uint8List bytes) async {
    await _client.storage
        .from(AppConstants.wardrobeBucket)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    return path;
  }

  String getPublicUrl(String path) {
    return _client.storage
        .from(AppConstants.wardrobeBucket)
        .getPublicUrl(path);
  }

  Future<void> deleteImage(String path) async {
    await _client.storage.from(AppConstants.wardrobeBucket).remove([path]);
  }

  // ── Wardrobe Items ────────────────────────────────────
  Future<List<WardrobeItem>> getWardrobeItems() async {
    final data = await _client
        .from('wardrobe_items')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map((json) => WardrobeItem.fromJson(json)).toList();
  }

  Future<WardrobeItem> addWardrobeItem(Map<String, dynamic> item) async {
    final data = await _client
        .from('wardrobe_items')
        .insert(item)
        .select()
        .single();
    return WardrobeItem.fromJson(data);
  }

  Future<void> deleteWardrobeItem(String id) async {
    await _client.from('wardrobe_items').delete().eq('id', id);
  }

  // ── Outfits ───────────────────────────────────────────
  Future<Outfit> createOutfit(Map<String, dynamic> outfit, List<Map<String, dynamic>> items) async {
    final outfitData = await _client
        .from('outfits')
        .insert(outfit)
        .select()
        .single();

    for (final item in items) {
      item['outfit_id'] = outfitData['id'];
      await _client.from('outfit_items').insert(item);
    }

    return Outfit.fromJson(outfitData);
  }

  Future<List<Outfit>> getOutfits() async {
    final data = await _client
        .from('outfits')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map((json) => Outfit.fromJson(json)).toList();
  }

  Future<List<OutfitItem>> getOutfitItems(String outfitId) async {
    final data = await _client
        .from('outfit_items')
        .select()
        .eq('outfit_id', outfitId);
    return data.map((json) => OutfitItem.fromJson(json)).toList();
  }

  // ── Fit Checks ────────────────────────────────────────
  Future<FitCheck> saveFitCheck(Map<String, dynamic> fitCheck) async {
    final data = await _client
        .from('fit_checks')
        .insert(fitCheck)
        .select()
        .single();
    return FitCheck.fromJson(data);
  }

  Future<List<FitCheck>> getFitChecks() async {
    final data = await _client
        .from('fit_checks')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map((json) => FitCheck.fromJson(json)).toList();
  }
}
