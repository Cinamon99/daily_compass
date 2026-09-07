import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_item.dart';
import '../services/storage_service.dart';
import '../utils/date_utils_x.dart';

/// 通知点击的回调入口。
/// 必须是顶层函数或静态方法，并加上 vm:entry-point 注解，
/// 否则 release 包在树摇后可能找不到入口。
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService.instance.handleTap(response.payload);
}

/// 封装闹钟 / 提醒的排程与权限管理。
///
/// 通知 ID 规划：
/// - 1：内置晨间提醒
/// - 2：内置晚间总结提醒
/// - 10 起：用户提醒按创建顺序分配
/// - 1000000 起：每周重复提醒派生 `1000000 + notifyId * 8 + weekday`
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String alarmChannelId = 'compass_alarm';
  static const String alarmChannelName = '闹钟';
  static const String alarmChannelDesc = '需要准时响铃的闹钟与强提醒';

  static const String reminderChannelId = 'compass_reminder';
  static const String reminderChannelName = '常规提醒';
  static const String reminderChannelDesc = '一般工作与生活提醒';

  static const int morningNotifyId = 1;
  static const int summaryNotifyId = 2;
  static const int weeklyIdBase = 1000000;

  bool _initialized = false;
  tz.Location _location = tz.UTC;

  /// 通知被点击时的外部回调（payload 携带 reminder id 或内置标识）
  void Function(String? payload)? onTap;

  static int weeklyId(int notifyId, int weekday) =>
      weeklyIdBase + notifyId * 8 + weekday;

  /// 只有安卓端才需要真正的闹钟能力。
  /// Windows / Mac 端直接跳过所有通知调用，否则插件没有对应实现会报错。
  static bool get supported => Platform.isAndroid;

  // ------------------------------------------------------------------ 初始化

  Future<void> init() async {
    if (!supported || _initialized) return;

    tz_data.initializeTimeZones();
    _location = await _resolveLocation();

    // 通知用纯白剪影图标，不能用自适应启动图标
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: handleResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _createChannels();
    _initialized = true;
  }

  /// 优先用设备上报的 IANA 时区；拿不到时按当前 UTC 偏移退化成 Etc/GMT±N。
  Future<tz.Location> _resolveLocation() async {
    String identifier = '';
    try {
      identifier = (await FlutterTimezone.getLocalTimezone()).identifier;
      return tz.getLocation(identifier);
    } catch (_) {
      // 继续走下面的兜底逻辑
    }
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final offsetHours = offsetMinutes ~/ 60;
    final name = offsetHours <= 0
        ? 'Etc/GMT+${offsetHours.abs()}'
        : 'Etc/GMT-$offsetHours';
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.UTC;
    }
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        alarmChannelId,
        alarmChannelName,
        description: alarmChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        reminderChannelId,
        reminderChannelName,
        description: reminderChannelDesc,
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  // ------------------------------------------------------------------ 权限

  /// 申请通知权限（Android 13+）与精确闹钟权限（Android 12+）。
  /// 返回是否具备通知权限。
  Future<bool> ensurePermissions({bool requestExactAlarms = true}) async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    final granted = await android.requestNotificationsPermission();
    if (requestExactAlarms) {
      try {
        await android.requestExactAlarmsPermission();
      } catch (_) {
        // 部分机型不支持跳转设置页，忽略即可
      }
    }
    return granted ?? true;
  }

  // ------------------------------------------------------------------ 同步排程

  /// 全量重排：先清空所有排程，再按当前数据重新下发。
  /// 数据量小，比增量维护更不容易出错。
  Future<void> syncAll({
    required List<ReminderItem> reminders,
    required AppSettings settings,
  }) async {
    if (!supported) return;
    await init();
    await _plugin.cancelAll();
    for (final item in reminders) {
      await _scheduleReminder(item);
    }
    await _scheduleBuiltIn(settings);
  }

  Future<void> _scheduleReminder(ReminderItem item) async {
    if (!item.enabled) return;
    final now = DateTime.now();

    switch (item.repeat) {
      case ReminderRepeat.once:
        final next = item.nextFireAt(now);
        if (next == null) return; // 已过期，不再排程
        await _zonedSchedule(
          id: item.notifyId,
          scheduled: next,
          details: _detailsFor(item),
          title: item.title,
          body: _bodyFor(item),
          payload: item.id,
        );
      case ReminderRepeat.daily:
        final next = item.nextFireAt(now);
        if (next == null) return;
        await _zonedSchedule(
          id: item.notifyId,
          scheduled: next,
          details: _detailsFor(item),
          title: item.title,
          body: _bodyFor(item),
          payload: item.id,
          match: DateTimeComponents.time,
        );
      case ReminderRepeat.weekly:
        for (final weekday in item.weekdays) {
          final next = _nextWeekdayAt(weekday, item.hour, item.minute, now);
          await _zonedSchedule(
            id: weeklyId(item.notifyId, weekday),
            scheduled: next,
            details: _detailsFor(item),
            title: item.title,
            body: _bodyFor(item),
            payload: item.id,
            match: DateTimeComponents.dayOfWeekAndTime,
          );
        }
    }
  }

  /// 内置引导提醒：晨间提示今日安排、晚间提示写总结
  Future<void> _scheduleBuiltIn(AppSettings settings) async {
    final now = DateTime.now();

    if (settings.morningEnabled) {
      final next = _nextTimeAt(
        settings.morningHour,
        settings.morningMinute,
        now,
      );
      await _zonedSchedule(
        id: morningNotifyId,
        scheduled: next,
        details: _alarmDetails(ticker: '早上好'),
        title: '早上好，新的一天开始了',
        body: '看看今天有哪些任务、备忘和提醒',
        payload: 'builtin:morning',
        match: DateTimeComponents.time,
      );
    }

    if (settings.summaryEnabled) {
      final next = _nextTimeAt(
        settings.summaryHour,
        settings.summaryMinute,
        now,
      );
      await _zonedSchedule(
        id: summaryNotifyId,
        scheduled: next,
        details: _alarmDetails(ticker: '该做总结了'),
        title: '该做今天的总结了',
        body: '花三分钟回顾一下，给今天打个分',
        payload: 'builtin:summary',
        match: DateTimeComponents.time,
      );
    }
  }

  Future<void> _zonedSchedule({
    required int id,
    required DateTime scheduled,
    required NotificationDetails details,
    required String title,
    required String body,
    String? payload,
    DateTimeComponents? match,
  }) async {
    final tzTime = tz.TZDateTime(
      _location,
      scheduled.year,
      scheduled.month,
      scheduled.day,
      scheduled.hour,
      scheduled.minute,
    );
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tzTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
      matchDateTimeComponents: match,
    );
  }

  DateTime _nextTimeAt(int hour, int minute, DateTime now) {
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  DateTime _nextWeekdayAt(int weekday, int hour, int minute, DateTime now) {
    for (var offset = 0; offset < 8; offset++) {
      final day = now.add(Duration(days: offset));
      if (day.weekday != weekday) continue;
      final candidate = DateTime(day.year, day.month, day.day, hour, minute);
      if (candidate.isAfter(now)) return candidate;
    }
    // 理论上走不到这里（一周内必然命中），兜底返回下周同一天
    return now.add(const Duration(days: 7));
  }

  NotificationDetails _detailsFor(ReminderItem item) {
    if (item.alarmStyle) {
      return _alarmDetails(ticker: item.title);
    }
    return _reminderDetails(ticker: item.title);
  }

  /// 闹钟样式：最大重要性 + 闹钟渠道 + 全屏意图 + 点亮屏幕 + 闹钟音。
  /// 用于用户「闹钟模式」提醒与内置的早/晚引导提醒，确保足够醒目。
  NotificationDetails _alarmDetails({String? ticker}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        alarmChannelId,
        alarmChannelName,
        channelDescription: alarmChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ticker: ticker,
        autoCancel: true,
      ),
    );
  }

  /// 稍后提醒：把当前闹钟延后几分钟再响一次（一次性闹钟样式通知）。
  Future<void> showSnooze(String title, {int minutes = 5, String? payload}) async {
    if (!supported) return;
    await init();
    final next = DateTime.now().add(Duration(minutes: minutes));
    final id = 700000 + (DateTime.now().millisecondsSinceEpoch % 100000);
    await _zonedSchedule(
      id: id,
      scheduled: next,
      details: _alarmDetails(ticker: title),
      title: title,
      body: '稍后提醒（$minutes分钟前响过）',
      payload: payload ?? 'snooze',
    );
  }

  /// 常规提醒渠道的样式：响铃 + 震动，但不抢占全屏
  NotificationDetails _reminderDetails({String? ticker}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        reminderChannelId,
        reminderChannelName,
        channelDescription: reminderChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        enableVibration: true,
        ticker: ticker,
      ),
    );
  }

  String _bodyFor(ReminderItem item) {
    final timeText = formatHm(item.hour, item.minute);
    if (item.note.trim().isNotEmpty) return item.note.trim();
    final scope = item.scope.label;
    switch (item.repeat) {
      case ReminderRepeat.once:
        return '$scope · $timeText · 临时提醒';
      case ReminderRepeat.daily:
        return '$scope · 每天 $timeText';
      case ReminderRepeat.weekly:
        return '$scope · ${weekdaysText(item.weekdays)} $timeText';
    }
  }

  // ------------------------------------------------------------------ 其他

  /// 立即发一条测试通知，用于验证权限与响铃是否正常
  Future<void> showTestNotification() async {
    if (!supported) return;
    await init();
    await _plugin.show(
      id: 999,
      title: '每日罗盘提醒测试',
      body: '如果你看到这条通知，说明闹钟可以正常工作',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          alarmChannelId,
          alarmChannelName,
          channelDescription: alarmChannelDesc,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
    );
  }

  Future<void> cancel(int id) async {
    if (!supported) return;
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    if (!supported) return;
    await _plugin.cancelAll();
  }

  Future<List<int>> pendingIds() async {
    if (!supported) return <int>[];
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((e) => e.id).toList();
  }

  void handleResponse(NotificationResponse response) =>
      handleTap(response.payload);

  void handleTap(String? payload) {
    onTap?.call(payload);
  }
}
