import 'package:flutter/foundation.dart';

import '../models/daily_review.dart';
import '../models/memo_item.dart';
import '../models/reminder_item.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/sync_payload.dart';
import '../utils/date_utils_x.dart';

/// 全局应用状态。所有页面共用同一份数据，
/// 任何写操作都会立即落盘并重新同步闹钟排程。
class AppState extends ChangeNotifier {
  AppState();

  final StorageService _storage = StorageService.instance;
  final NotificationService _notifications = NotificationService.instance;

  List<MemoItem> _memos = <MemoItem>[];
  List<ReminderItem> _reminders = <ReminderItem>[];
  List<DailyReview> _reviews = <DailyReview>[];
  AppSettings _settings = AppSettings();

  bool _loaded = false;
  bool _scheduling = false;

  bool get isLoaded => _loaded;

  /// 对外展示的数据，已过滤掉软删除项
  List<MemoItem> get memos => List.unmodifiable(_liveMemos);
  List<ReminderItem> get reminders => List.unmodifiable(_liveReminders);
  List<DailyReview> get reviews => List.unmodifiable(_liveReviews);
  AppSettings get settings => _settings;

  /// 含已删除项的全量数据，仅同步时使用
  List<MemoItem> get allMemos => List.unmodifiable(_memos);
  List<ReminderItem> get allReminders => List.unmodifiable(_reminders);
  List<DailyReview> get allReviews => List.unmodifiable(_reviews);

  List<MemoItem> get _liveMemos => _memos.where((e) => !e.deleted).toList();
  List<ReminderItem> get _liveReminders =>
      _reminders.where((e) => !e.deleted).toList();
  List<DailyReview> get _liveReviews =>
      _reviews.where((e) => !e.deleted).toList();

  // ------------------------------------------------------------------ 载入

  Future<void> load() async {
    if (_loaded) return;
    _memos = await _storage.loadMemos();
    _reminders = await _storage.loadReminders();
    _reviews = await _storage.loadReviews();
    _settings = await _storage.loadSettings();
    _loaded = true;
    notifyListeners();
    await reschedule();
  }

  /// 重新下发所有闹钟排程（数据变更、应用回到前台时调用）
  Future<void> reschedule() async {
    if (_scheduling) return;
    _scheduling = true;
    try {
      await _notifications.syncAll(
        reminders: _liveReminders,
        settings: _settings,
      );
    } catch (e) {
      debugPrint('同步闹钟排程失败: $e');
    } finally {
      _scheduling = false;
    }
  }

  // ------------------------------------------------------------------ 备忘

  Future<void> addMemo(MemoItem memo) async {
    memo.touch();
    _memos = [memo, ..._memos];
    await _storage.saveMemos(_memos);
    notifyListeners();
  }

  Future<void> updateMemo(MemoItem memo) async {
    final index = _memos.indexWhere((e) => e.id == memo.id);
    if (index == -1) return;
    memo.touch();
    _memos = [..._memos]..[index] = memo;
    await _storage.saveMemos(_memos);
    notifyListeners();
  }

  /// 软删除：保留记录并打标记，这样同步时另一端才会跟着删掉
  Future<void> removeMemo(String id) async {
    final index = _memos.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _memos[index].deleted = true;
    _memos[index].touch();
    await _storage.saveMemos(_memos);
    notifyListeners();
  }

  Future<void> toggleMemoDone(String id, bool value) async {
    final index = _memos.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final memo = _memos[index];
    memo.done = value;
    memo.completedAt = value ? DateTime.now() : null;
    memo.touch();
    await _storage.saveMemos(_memos);
    notifyListeners();
  }

  /// 清空某一分类下已完成的备忘（软删除）
  Future<void> clearCompletedMemos(MemoCategory category) async {
    for (final memo in _memos) {
      if (memo.category == category && memo.done && !memo.deleted) {
        memo.deleted = true;
        memo.touch();
      }
    }
    await _storage.saveMemos(_memos);
    notifyListeners();
  }

  List<MemoItem> memosOf(MemoCategory category) =>
      _liveMemos.where((e) => e.category == category).toList();

  /// 今天排了期的备忘
  List<MemoItem> get todayMemos {
    final today = todayKey();
    return _liveMemos.where((e) => e.planDate == today).toList();
  }

  /// 排期已过但还没完成的备忘（逾期）
  List<MemoItem> get overdueMemos {
    final today = todayKey();
    return _liveMemos
        .where((e) => !e.done && e.planDate != null && e.planDate!.compareTo(today) < 0)
        .toList();
  }

  /// 今日完成进度 0~1；今天没有任何排期时返回 0
  double get todayProgress {
    final list = todayMemos;
    if (list.isEmpty) return 0;
    final done = list.where((e) => e.done).length;
    return done / list.length;
  }

  // ------------------------------------------------------------------ 提醒

  Future<void> addReminder(ReminderItem reminder) async {
    reminder.touch();
    _reminders = [reminder, ..._reminders];
    await _storage.saveReminders(_reminders);
    notifyListeners();
    await reschedule();
  }

  Future<void> updateReminder(ReminderItem reminder) async {
    final index = _reminders.indexWhere((e) => e.id == reminder.id);
    if (index == -1) return;
    reminder.touch();
    _reminders = [..._reminders]..[index] = reminder;
    await _storage.saveReminders(_reminders);
    notifyListeners();
    await reschedule();
  }

  /// 软删除：保留记录并打标记，同时取消它占用的本地闹钟
  Future<void> removeReminder(String id) async {
    final index = _reminders.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final target = _reminders[index];
    target.deleted = true;
    target.touch();
    await _storage.saveReminders(_reminders);
    notifyListeners();
    // 取消它占用的所有通知 ID
    await _notifications.cancel(target.notifyId);
    for (var wd = 1; wd <= 7; wd++) {
      await _notifications.cancel(NotificationService.weeklyId(target.notifyId, wd));
    }
    await reschedule();
  }

  Future<void> toggleReminder(String id, bool value) async {
    final index = _reminders.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _reminders[index].enabled = value;
    _reminders[index].touch();
    await _storage.saveReminders(_reminders);
    notifyListeners();
    await reschedule();
  }

  Future<int> allocateNotifyId() => _storage.nextNotifyId();

  /// 日常提醒（每天 / 每周）
  List<ReminderItem> get routineReminders =>
      _liveReminders.where((e) => e.isRoutine).toList();

  /// 临时提醒（一次性）
  List<ReminderItem> get tempReminders =>
      _liveReminders.where((e) => !e.isRoutine).toList();

  /// 接下来会响的提醒，按时间升序
  List<ReminderItem> upcomingReminders({int limit = 5}) {
    final now = DateTime.now();
    final entries = <({ReminderItem item, DateTime at})>[];
    for (final item in _liveReminders) {
      final at = item.nextFireAt(now);
      if (at != null) entries.add((item: item, at: at));
    }
    entries.sort((a, b) => a.at.compareTo(b.at));
    return entries.take(limit).map((e) => e.item).toList();
  }

  /// 距离下一次提醒还有多久；没有启用中的提醒则返回 null
  ({ReminderItem item, DateTime at})? get nextReminder {
    final now = DateTime.now();
    ({ReminderItem item, DateTime at})? best;
    for (final item in _liveReminders) {
      final at = item.nextFireAt(now);
      if (at == null) continue;
      if (best == null || at.isBefore(best.at)) {
        best = (item: item, at: at);
      }
    }
    return best;
  }

  /// 今天还会响的提醒（含已过时间的，用于主页时间轴展示）
  List<ReminderItem> todayReminders() {
    final now = DateTime.now();
    final today = now.weekday;
    return _liveReminders.where((item) {
      if (!item.enabled) return false;
      switch (item.repeat) {
        case ReminderRepeat.daily:
          return true;
        case ReminderRepeat.weekly:
          return item.weekdays.contains(today);
        case ReminderRepeat.once:
          return item.date == dateKeyOf(now);
      }
    }).toList()
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  }

  // ------------------------------------------------------------------ 总结

  DailyReview? reviewOf(String dateKey) {
    for (final review in _liveReviews) {
      if (review.dateKey == dateKey) return review;
    }
    return null;
  }

  Future<void> saveReview(DailyReview review) async {
    review.touch();
    final index = _reviews.indexWhere((e) => e.dateKey == review.dateKey);
    if (index == -1) {
      _reviews = [review, ..._reviews];
    } else {
      _reviews = [..._reviews]..[index] = review;
    }
    await _storage.saveReviews(_reviews);
    notifyListeners();
  }

  /// 软删除：保留记录并打标记，这样同步时另一端才会跟着删掉
  Future<void> removeReview(String dateKey) async {
    final index = _reviews.indexWhere((e) => e.dateKey == dateKey);
    if (index == -1) return;
    _reviews[index].deleted = true;
    _reviews[index].touch();
    await _storage.saveReviews(_reviews);
    notifyListeners();
  }

  /// 按日期倒序排列的历史记录
  List<DailyReview> get sortedReviews {
    final list = [..._liveReviews];
    list.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return list;
  }

  /// 最近 [days] 天的评分序列（从旧到新），没写的那天为 null
  List<({String dateKey, int? score})> recentScores(int days) {
    final result = <({String dateKey, int? score})>[];
    final today = DateTime.now();
    for (var i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final key = dateKeyOf(day);
      result.add((dateKey: key, score: reviewOf(key)?.score));
    }
    return result;
  }

  double get averageScore {
    if (_liveReviews.isEmpty) return 0;
    final total = _liveReviews.fold<int>(0, (sum, e) => sum + e.score);
    return total / _liveReviews.length;
  }

  /// 连续记录天数（今天没写则从昨天往前算）
  int get reviewStreak {
    final today = DateTime.now();
    var cursor = DateTime.now();
    if (reviewOf(dateKeyOf(today)) == null) {
      cursor = today.subtract(const Duration(days: 1));
      if (reviewOf(dateKeyOf(cursor)) == null) return 0;
    }
    var streak = 0;
    while (reviewOf(dateKeyOf(cursor)) != null) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ------------------------------------------------------------------ 设置

  Future<void> updateSettings(AppSettings settings) async {
    settings.touch();
    _settings = settings;
    await _storage.saveSettings(settings);
    notifyListeners();
    await reschedule();
  }

  // ------------------------------------------------------------------ 同步

  /// 构建本端用于同步的数据包（含软删除记录，这样对方才知道哪些被删了）
  SyncPayload buildPayload({
    required String deviceId,
    required String deviceName,
  }) {
    return SyncPayload(
      memos: allMemos,
      reminders: allReminders,
      reviews: allReviews,
      settings: _settings,
      deviceId: deviceId,
      deviceName: deviceName,
    );
  }

  /// 应用同步合并后的结果，必要时重新分配重复的通知 ID
  Future<void> applyMerged(SyncPayload payload) async {
    _memos = payload.memos;
    _reminders = payload.reminders;
    _reviews = payload.reviews;
    _settings = payload.settings;

    await _ensureUniqueNotifyIds();
    await _storage.saveMemos(_memos);
    await _storage.saveReminders(_reminders);
    await _storage.saveReviews(_reviews);
    await _storage.saveSettings(_settings);
    notifyListeners();
    await reschedule();
  }

  /// 两端各自分配的通知 ID 在合并后可能撞号，这里把重复的重新分配一个
  Future<void> _ensureUniqueNotifyIds() async {
    final used = <int>{};
    var maxId = 9; // 1~9 保留给内置的晨间/晚间提醒
    for (final item in _reminders) {
      if (item.notifyId > maxId) maxId = item.notifyId;
    }
    for (final item in _reminders) {
      if (used.add(item.notifyId)) continue;
      maxId++;
      item.notifyId = maxId;
      used.add(maxId);
    }
    await _storage.ensureNotifyIdAbove(maxId + 1);
  }
}
