import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_screen.dart';
import 'features/wardrobe/add_item_screen.dart';
import 'features/outfits/outfit_screen.dart';
import 'features/fit_check/fit_check_screen.dart';
import 'features/subscription/paywall_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      if (kDemoMode) return null;

      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isOnAuth = state.matchedLocation == '/auth';

      if (!isLoggedIn && !isOnAuth) return '/auth';
      if (isLoggedIn && isOnAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
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
        builder: (context, state) => FitCheckScreen(
          outfitId: state.pathParameters['outfitId']!,
        ),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
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
