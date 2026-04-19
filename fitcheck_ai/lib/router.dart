import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'features/auth/auth_screen.dart';
import 'features/analytics/closet_value_screen.dart';
import 'features/battles/battle_view_screen.dart';
import 'features/battles/create_battle_screen.dart';
import 'features/feed/stranger_feed_screen.dart';
import 'features/home/home_screen.dart';
import 'features/wardrobe/add_item_screen.dart';
import 'features/outfits/outfit_screen.dart';
import 'features/fit_check/fit_check_screen.dart';
import 'features/subscription/paywall_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/onboarding/instant_fit_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) {
      if (kDemoMode) return null;

      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;

      // Pre-signup paths that must stay accessible without auth.
      const publicPaths = ['/welcome', '/instant-fit', '/auth'];
      final isPublicPath = publicPaths.contains(loc) || loc.startsWith('/b/');

      if (!isLoggedIn && !isPublicPath) return '/welcome';
      if (isLoggedIn && (loc == '/welcome' || loc == '/auth')) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/instant-fit',
        builder: (context, state) {
          final bytes = state.extra as Uint8List?;
          if (bytes == null) {
            // Fallback if someone lands here without bytes (e.g. reload).
            return const WelcomeScreen();
          }
          return InstantFitScreen(imageBytes: bytes);
        },
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/feed',
        builder: (context, state) => const StrangerFeedScreen(),
      ),
      GoRoute(
        path: '/closet-value',
        builder: (context, state) => const ClosetValueScreen(),
      ),
      GoRoute(
        path: '/wardrobe/add',
        builder: (context, state) => const AddItemScreen(),
      ),
      GoRoute(
        path: '/outfit/:id',
        builder: (context, state) => OutfitScreen(
          outfitId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/fit-check/:outfitId',
        builder: (context, state) {
          final bytes = state.extra is Uint8List
              ? state.extra as Uint8List
              : null;
          return FitCheckScreen(
            outfitId: state.pathParameters['outfitId']!,
            imageBytes: bytes,
          );
        },
      ),
      GoRoute(
        path: '/battle/new',
        builder: (context, state) {
          final bytes = state.extra is Uint8List
              ? state.extra as Uint8List
              : null;
          return CreateBattleScreen(initialImage: bytes);
        },
      ),
      // In-app battle view (owner or already-signed-in user).
      GoRoute(
        path: '/battle/:code',
        builder: (context, state) => BattleViewScreen(
          code: state.pathParameters['code']!,
        ),
      ),
      // Deep-link slug matches grwm.app/b/<code>.
      GoRoute(
        path: '/b/:code',
        builder: (context, state) => BattleViewScreen(
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) {
          final reason = state.uri.queryParameters['reason'];
          return PaywallScreen(reason: reason);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
});
