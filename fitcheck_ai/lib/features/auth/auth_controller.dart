import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/supabase_service.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  late SupabaseService _supabase;

  @override
  FutureOr<void> build() {
    _supabase = ref.read(supabaseServiceProvider);
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _supabase.signInWithApple();
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _supabase.signInWithGoogle();
    });
  }

  Future<void> signOut() async {
    await _supabase.signOut();
  }
}
