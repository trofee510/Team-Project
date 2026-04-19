import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'weather_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(weather: ref.watch(weatherServiceProvider));
});

/// Local daily nudge: "What are you wearing today?" with weather delta vs
/// yesterday + streak loss aversion. Rescheduled every launch so the content
/// stays fresh for tomorrow morning.
class NotificationService {
  final WeatherService weather;

  static const _channelId = 'grwm_daily';
  static const _channelName = 'Daily fit check';
  static const _notificationId = 7001;

  static const _prefLastTempF = 'notif_last_temp_f';
  static const _prefLastScheduledAt = 'notif_last_scheduled_at';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  NotificationService({required this.weather});

  Future<void> init() async {
    if (_inited) return;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to UTC — scheduling will still fire, just not at local 7am.
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _inited = true;
  }

  Future<bool> requestPermissions() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> cancelDaily() async {
    await init();
    await _plugin.cancel(_notificationId);
  }

  /// Schedules (or reschedules) the daily nudge for tomorrow at [time].
  /// Fires once; after delivery, call this again to line up the next day.
  /// [streak] / [scoredToday] drive the loss-aversion copy.
  Future<void> scheduleDailyNudge({
    required String timeHHmm,
    required int streak,
    required bool scoredToday,
    String? location,
  }) async {
    await init();

    final parts = timeHHmm.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? 7;
    final minute = int.tryParse(parts[1]) ?? 0;

    final body = await _buildBody(
      streak: streak,
      scoredToday: scoredToday,
      location: location,
    );

    final now = tz.TZDateTime.now(tz.local);
    var fireAt = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!fireAt.isAfter(now)) {
      fireAt = fireAt.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notificationId,
      'What are you wearing today?',
      body,
      fireAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Your daily fit check nudge',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'daily_nudge',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefLastScheduledAt,
      DateTime.now().toIso8601String(),
    );
  }

  Future<String> _buildBody({
    required int streak,
    required bool scoredToday,
    String? location,
  }) async {
    String weatherLine = '';
    try {
      final w = await weather.getCurrentWeather(location: location ?? '');
      if (w != null) {
        final prefs = await SharedPreferences.getInstance();
        final lastF = prefs.getDouble(_prefLastTempF);
        await prefs.setDouble(_prefLastTempF, w.tempF);

        if (lastF != null) {
          final delta = (w.tempF - lastF).round();
          if (delta.abs() >= 3) {
            weatherLine = delta > 0
                ? '${w.tempDisplay} — ${delta}°F warmer than yesterday.'
                : '${w.tempDisplay} — ${delta.abs()}°F colder than yesterday.';
          } else {
            weatherLine = '${w.tempDisplay} — similar to yesterday.';
          }
        } else {
          weatherLine = '${w.tempDisplay} outside. ${w.dressAdvice}.';
        }
      }
    } catch (_) {
      // Weather best-effort only.
    }

    String streakLine;
    if (scoredToday) {
      streakLine = 'Streak: $streak 🔥 Keep it going tomorrow.';
    } else if (streak > 0) {
      streakLine = 'Your $streak-day streak ends tonight if you skip.';
    } else {
      streakLine = 'Start a streak today — tap to score your fit.';
    }

    return [weatherLine, streakLine]
        .where((s) => s.isNotEmpty)
        .join(' ');
  }
}
