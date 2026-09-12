import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/prediction/reminder_plan.dart';

/// 通知通道与提醒调度。
///
/// 安卓端提醒可靠性依赖三项：通知权限、精确闹钟权限、电池优化白名单。
/// 缺失任意一项都可能导致提醒不响，由「提醒自检」页负责检测与引导。
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// 领域层的提醒类型 → 平台通知 id。id 必须稳定，否则重排时无法覆盖旧通知。
  static int idFor(ReminderKind kind) => switch (kind) {
        ReminderKind.prePeriod => 1001,
        ReminderKind.periodStart => 1002,
        ReminderKind.fertile => 1003,
        ReminderKind.ovulation => 1004,
        ReminderKind.ongoingCheck => 1005,
        ReminderKind.overduePrompt => 1006,
      };

  static const String channelReminder = 'yuejingben_reminder';
  static const String channelName = '经期提醒';

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelReminder,
        channelName,
        description: '经期、排卵期相关提醒',
        importance: Importance.high,
      ),
    );
  }

  Future<bool> requestNotificationPermission() async {
    final granted = await _android?.requestNotificationsPermission();
    if (granted == true) return true;
    // 低版本兜底。
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> hasNotificationPermission() async {
    final enabled = await _android?.areNotificationsEnabled();
    if (enabled != null) return enabled;
    return Permission.notification.status.then((s) => s.isGranted);
  }

  Future<bool> requestExactAlarmPermission() async {
    final granted = await _android?.requestExactAlarmsPermission();
    if (granted == true) return true;
    return Permission.scheduleExactAlarm.status.then((s) => s.isGranted);
  }

  Future<bool> hasExactAlarmPermission() async {
    final can = await _android?.canScheduleExactNotifications();
    if (can != null) return can;
    return Permission.scheduleExactAlarm.status.then((s) => s.isGranted);
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return true;
    return (await Permission.ignoreBatteryOptimizations.request()).isGranted;
  }

  Future<bool> hasIgnoreBatteryOptimizations() =>
      Permission.ignoreBatteryOptimizations.status.then((s) => s.isGranted);

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  /// 精确时间提醒（支持锁屏与低电耗模式）。
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelReminder,
          channelName,
          channelDescription: '经期、排卵期相关提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
