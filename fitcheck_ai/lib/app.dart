import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'router.dart';
import 'services/notification_service.dart';
import 'services/streak_service.dart';
import 'services/supabase_service.dart';

class GRWMApp extends ConsumerStatefulWidget {
  const GRWMApp({super.key});

  @override
  ConsumerState<GRWMApp> createState() => _GRWMAppState();
}

class _GRWMAppState extends ConsumerState<GRWMApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _wireDeepLinks();
    // Schedule the daily nudge once the UI is up; safe to run every launch
    // because the service reschedules idempotently for tomorrow morning.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleNudge());
  }

  Future<void> _wireDeepLinks() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _handleUri(initial);
    _sub = _appLinks.uriLinkStream.listen(_handleUri);
  }

  void _handleUri(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'b') {
      final code = segments[1].toUpperCase();
      ref.read(routerProvider).go('/b/$code');
    }
  }

  Future<void> _scheduleNudge() async {
    try {
      final supabase = ref.read(supabaseServiceProvider);
      if (supabase.currentUser == null) return;

      final profile = await supabase.getMyProfile();
      if (profile == null || !profile.notificationsEnabled) return;

      final notif = ref.read(notificationServiceProvider);
      await notif.requestPermissions(); // no-op if already granted
      final streak = ref.read(streakServiceProvider);

      await notif.scheduleDailyNudge(
        timeHHmm: profile.notificationTime ?? '07:00',
        streak: streak.currentStreak,
        scoredToday: streak.scoredToday,
        location: profile.location,
      );
    } catch (_) {
      // Best-effort — never block app startup on notification plumbing.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'GRWM',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
