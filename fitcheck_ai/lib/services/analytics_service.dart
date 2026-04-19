import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../core/constants.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// Thin facade over Sentry (crashes + perf) and PostHog (funnel events).
/// Keep event names stable — dashboards + alerts will be built on them.
class AnalyticsService {
  /// Known event names. Centralized so typos don't fragment the funnel.
  static const String onboardingStarted = 'onboarding_started';
  static const String instantFitScored = 'instant_fit_scored';
  static const String signUpCompleted = 'sign_up_completed';
  static const String fitCheckStarted = 'fit_check_started';
  static const String fitCheckSucceeded = 'fit_check_succeeded';
  static const String fitCheckFailed = 'fit_check_failed';
  static const String fitCheckLimitHit = 'fit_check_limit_hit';
  static const String paywallViewed = 'paywall_viewed';
  static const String paywallPurchaseStarted = 'paywall_purchase_started';
  static const String paywallPurchaseSucceeded = 'paywall_purchase_succeeded';
  static const String paywallPurchaseFailed = 'paywall_purchase_failed';
  static const String shareCardGenerated = 'share_card_generated';
  static const String battleCreated = 'battle_created';
  static const String battleRatingSubmitted = 'battle_rating_submitted';
  static const String strangerRatingSubmitted = 'stranger_rating_submitted';

  /// Capture a funnel event. Silently no-ops if PostHog isn't configured.
  Future<void> track(String event, {Map<String, Object>? props}) async {
    try {
      await Posthog().capture(eventName: event, properties: props);
    } catch (_) {}
  }

  Future<void> identify(String userId, {Map<String, Object>? props}) async {
    try {
      await Posthog().identify(userId: userId, userProperties: props);
    } catch (_) {}
    Sentry.configureScope((scope) => scope.setUser(SentryUser(id: userId)));
  }

  Future<void> reset() async {
    try {
      await Posthog().reset();
    } catch (_) {}
    Sentry.configureScope((scope) => scope.setUser(null));
  }

  /// Capture an arbitrary error with breadcrumbs.
  Future<void> captureError(Object err, StackTrace? st,
      {String? hint, Map<String, Object>? extras}) async {
    try {
      await Sentry.captureException(
        err,
        stackTrace: st,
        hint: hint == null ? null : Hint.withMap({'note': hint}),
        withScope: extras == null
            ? null
            : (scope) {
                extras.forEach(scope.setExtra);
              },
      );
    } catch (_) {}
  }
}

/// Init both SDKs and invoke [runApp] inside Sentry's zone guard.
/// Call from main() instead of runApp() directly.
Future<void> initObservabilityAndRun(Future<void> Function() body) async {
  final dsn = AppConstants.sentryDsn;
  final posthogKey = AppConstants.posthogKey;

  Future<void> boot() async {
    if (posthogKey.isNotEmpty) {
      try {
        final config = PostHogConfig(posthogKey)
          ..host = AppConstants.posthogHost
          ..captureApplicationLifecycleEvents = true
          ..debug = false;
        await Posthog().setup(config);
      } catch (_) {}
    }
    await body();
  }

  if (dsn.isEmpty) {
    await boot();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = 0.2;
      options.profilesSampleRate = 0.2;
      options.attachStacktrace = true;
      options.sendDefaultPii = false;
    },
    appRunner: boot,
  );
}
