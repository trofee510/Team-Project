import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wardrobe_item.dart';
import '../models/outfit.dart';
import '../models/fit_check.dart';
import '../models/user_profile.dart';
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

  /// Sends a passwordless magic-link / OTP email. The user confirms by
  /// tapping the link (deep-links back into the app via
  /// com.grwm.app://login-callback) or pastes the 6-digit OTP.
  Future<void> signInWithEmailOtp(String email) {
    return _client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: 'com.grwm.app://login-callback',
    );
  }

  /// Verifies an OTP code for the given email (pasted from inbox).
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim(),
      token: token.trim(),
    );
  }

  // ── User Profile ──────────────────────────────────────
  Future<UserProfile?> getMyProfile() async {
    if (currentUser == null) return null;
    final row = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(row);
  }

  Future<void> updateMyProfile(Map<String, dynamic> changes) async {
    await _client
        .from('user_profiles')
        .update(changes)
        .eq('user_id', userId);
  }

  // ── Storage ───────────────────────────────────────────
  //
  // Two buckets:
  //   - grwm-private: wardrobe + personal fit-check images. Read with signed
  //     URLs (1h TTL) — never public.
  //   - grwm-public: battle images + opted-in public fit checks. CDN-served.
  //
  // Legacy [uploadImage] + [getPublicUrl] still call the private bucket so
  // existing code paths keep working during migration.
  Future<String> uploadImage(String path, Uint8List bytes,
      {String? bucket}) async {
    await _client.storage
        .from(bucket ?? AppConstants.privateBucket)
        .uploadBinary(path, bytes,
            fileOptions: const FileOptions(upsert: true));
    return path;
  }

  Future<String> uploadToPublic(String path, Uint8List bytes) async {
    await _client.storage
        .from(AppConstants.publicBucket)
        .uploadBinary(path, bytes,
            fileOptions: const FileOptions(upsert: true));
    return path;
  }

  /// Returns a 1-hour signed URL for the private bucket. Use this for all
  /// wardrobe / personal fit-check images.
  Future<String> getSignedUrl(String path, {int ttlSeconds = 3600}) {
    return _client.storage
        .from(AppConstants.privateBucket)
        .createSignedUrl(path, ttlSeconds);
  }

  /// CDN URL for the public bucket. Use this for battles + opted-in public fits.
  String getPublicCdnUrl(String path) {
    return _client.storage
        .from(AppConstants.publicBucket)
        .getPublicUrl(path);
  }

  /// Legacy shim — returns the best-guess URL based on path prefix.
  /// Prefer [getSignedUrl] or [getPublicCdnUrl] in new code.
  String getPublicUrl(String path) {
    final segments = path.split('/');
    final isPublicPath =
        segments.isNotEmpty && ['battles', 'fitchecks'].contains(segments.first);
    if (isPublicPath) return getPublicCdnUrl(path);
    return _client.storage.from(AppConstants.privateBucket).getPublicUrl(path);
  }

  Future<void> deleteImage(String path, {String? bucket}) async {
    await _client.storage
        .from(bucket ?? AppConstants.privateBucket)
        .remove([path]);
  }

  // ── Wardrobe Items (paginated) ────────────────────────
  static const int _pageSize = 50;

  Future<List<WardrobeItem>> getWardrobeItems({int offset = 0, int limit = _pageSize}) async {
    final data = await _client
        .from('wardrobe_items')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
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

  // ── Outfits (paginated) ───────────────────────────────
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

  Future<List<Outfit>> getOutfits({int offset = 0, int limit = _pageSize}) async {
    final data = await _client
        .from('outfits')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return data.map((json) => Outfit.fromJson(json)).toList();
  }

  Future<List<OutfitItem>> getOutfitItems(String outfitId) async {
    final data = await _client
        .from('outfit_items')
        .select()
        .eq('outfit_id', outfitId);
    return data.map((json) => OutfitItem.fromJson(json)).toList();
  }

  // ── Fit Checks (paginated) ────────────────────────────
  Future<FitCheck> saveFitCheck(Map<String, dynamic> fitCheck) async {
    final data = await _client
        .from('fit_checks')
        .insert(fitCheck)
        .select()
        .single();
    return FitCheck.fromJson(data);
  }

  Future<List<FitCheck>> getFitChecks({int offset = 0, int limit = _pageSize}) async {
    final data = await _client
        .from('fit_checks')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return data.map((json) => FitCheck.fromJson(json)).toList();
  }

  // ── Subscribers ───────────────────────────────────────
  /// Live Pro status from the server (never trust client-only flags).
  Future<bool> fetchIsPro() async {
    if (currentUser == null) return false;
    final row = await _client
        .from('subscribers')
        .select('is_pro, expires_at')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return false;
    final isPro = row['is_pro'] == true;
    final exp = row['expires_at'];
    if (!isPro) return false;
    if (exp == null) return true;
    final expiresAt = DateTime.parse(exp as String);
    return expiresAt.isAfter(DateTime.now());
  }
}
