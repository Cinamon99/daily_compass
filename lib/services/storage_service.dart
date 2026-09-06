import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_review.dart';
import '../models/memo_item.dart';
import '../models/reminder_item.dart';

/// 应用设置：两个内置的引导型提醒
class AppSettings {
  AppSettings({
    this.morningEnabled = true,
    this.morningHour = 8,
    this.morningMinute = 0,
    this.summaryEnabled = true,
    this.summaryHour = 21,
    this.summaryMinute = 30,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// 晨间提醒：提示今天的任务与日程
  bool morningEnabled;
  int morningHour;
  int morningMinute;

  /// 晚间提醒：提示写每日总结
  bool summaryEnabled;
  int summaryHour;
  int summaryMinute;

  /// 设置的最后修改时间，同步时用它判断哪端的设置更新
  DateTime updatedAt;

  void touch() {
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'morningEnabled': morningEnabled,
        'morningHour': morningHour,
        'morningMinute': morningMinute,
        'summaryEnabled': summaryEnabled,
        'summaryHour': summaryHour,
        'summaryMinute': summaryMinute,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        morningEnabled: (json['morningEnabled'] as bool?) ?? true,
        morningHour: (json['morningHour'] as int?) ?? 8,
        morningMinute: (json['morningMinute'] as int?) ?? 0,
        summaryEnabled: (json['summaryEnabled'] as bool?) ?? true,
        summaryHour: (json['summaryHour'] as int?) ?? 21,
        summaryMinute: (json['summaryMinute'] as int?) ?? 30,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}

/// 基于 SharedPreferences 的本地持久化。
/// 所有数据以 JSON 数组字符串形式存放，读写都在主线程完成，
/// 数据量对个人应用来说足够小，不会有性能问题。
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const _kMemos = 'data.memos';
  static const _kReminders = 'data.reminders';
  static const _kReviews = 'data.reviews';
  static const _kSettings = 'data.settings';
  static const _kNextNotifyId = 'data.next_notify_id';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ---------------------------------------------------------------- 备忘

  Future<List<MemoItem>> loadMemos() async {
    final raw = (await prefs).getString(_kMemos);
    return _decodeList(raw, MemoItem.fromJson);
  }

  Future<void> saveMemos(List<MemoItem> items) async {
    await _saveList(_kMemos, items, (e) => e.toJson());
  }

  // ---------------------------------------------------------------- 提醒

  Future<List<ReminderItem>> loadReminders() async {
    final raw = (await prefs).getString(_kReminders);
    return _decodeList(raw, ReminderItem.fromJson);
  }

  Future<void> saveReminders(List<ReminderItem> items) async {
    await _saveList(_kReminders, items, (e) => e.toJson());
  }

  /// 分配下一个通知 ID。用户提醒从 10 开始，1~9 保留给内置提醒。
  Future<int> nextNotifyId() async {
    final p = await prefs;
    final current = p.getInt(_kNextNotifyId) ?? 10;
    await p.setInt(_kNextNotifyId, current + 1);
    return current;
  }

  /// 把 ID 计数器推进到 [value] 之上。
  /// 两端各自分配过的 ID 在同步后可能撞号，合并时用这个方法把计数器抬到安全值。
  Future<void> ensureNotifyIdAbove(int value) async {
    final p = await prefs;
    final current = p.getInt(_kNextNotifyId) ?? 10;
    if (value > current) {
      await p.setInt(_kNextNotifyId, value);
    }
  }

  // ---------------------------------------------------------------- 总结

  Future<List<DailyReview>> loadReviews() async {
    final raw = (await prefs).getString(_kReviews);
    return _decodeList(raw, DailyReview.fromJson);
  }

  Future<void> saveReviews(List<DailyReview> items) async {
    await _saveList(_kReviews, items, (e) => e.toJson());
  }

  // ---------------------------------------------------------------- 设置

  Future<AppSettings> loadSettings() async {
    final raw = (await prefs).getString(_kSettings);
    if (raw == null || raw.isEmpty) return AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
    } catch (_) {
      // 数据损坏时回退到默认设置
    }
    return AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await (await prefs).setString(_kSettings, jsonEncode(settings.toJson()));
  }

  // ---------------------------------------------------------------- 工具

  List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(fromJson)
            .toList();
      }
    } catch (_) {
      // 解析失败时返回空列表，避免整个应用崩溃
    }
    return <T>[];
  }

  Future<void> _saveList<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final encoded = jsonEncode(items.map(toJson).toList());
    await (await prefs).setString(key, encoded);
  }
}
