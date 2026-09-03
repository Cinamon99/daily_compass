import '../utils/id.dart';

/// 重复规则：
/// - [once]   临时提醒，只在 [ReminderItem.date] 当天响一次
/// - [daily]  日常提醒，每天固定时间
/// - [weekly] 日常提醒，每周固定几天
enum ReminderRepeat { once, daily, weekly }

extension ReminderRepeatX on ReminderRepeat {
  String get label {
    switch (this) {
      case ReminderRepeat.once:
        return '临时';
      case ReminderRepeat.daily:
        return '每天';
      case ReminderRepeat.weekly:
        return '每周';
    }
  }

  int get code => index;

  static ReminderRepeat fromCode(int code) =>
      ReminderRepeat.values[code.clamp(0, ReminderRepeat.values.length - 1)];
}

/// 提醒归属：工作 或 生活
enum ReminderScope { work, life }

extension ReminderScopeX on ReminderScope {
  String get label => this == ReminderScope.work ? '工作' : '生活';
  int get code => this == ReminderScope.work ? 0 : 1;

  static ReminderScope fromCode(int code) =>
      code == 1 ? ReminderScope.life : ReminderScope.work;
}

/// 一条提醒 / 闹钟。
/// 通知 ID 由 [notifyId] 固定分配；每周重复时会派生
/// `notifyId * 8 + weekday` 共 7 个 ID，因此 [notifyId] 必须唯一且从小整数开始。
class ReminderItem {
  ReminderItem({
    String? id,
    required this.notifyId,
    required this.title,
    this.note = '',
    this.repeat = ReminderRepeat.daily,
    this.weekdays = const [],
    required this.hour,
    this.minute = 0,
    this.date,
    this.scope = ReminderScope.life,
    this.enabled = true,
    this.alarmStyle = true,
    DateTime? createdAt,
    this.lastFiredAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final int notifyId;
  String title;
  String note;
  ReminderRepeat repeat;
  List<int> weekdays;
  int hour;
  int minute;
  /// 仅 [ReminderRepeat.once] 使用的日期键（yyyy-MM-dd）
  String? date;
  ReminderScope scope;
  bool enabled;
  /// true = 闹钟模式（响铃 + 震动 + 全屏），false = 普通静默通知
  bool alarmStyle;
  final DateTime createdAt;
  DateTime? lastFiredAt;

  /// 该提醒属于"日常"还是"临时"
  bool get isRoutine => repeat != ReminderRepeat.once;

  Map<String, dynamic> toJson() => {
        'id': id,
        'notifyId': notifyId,
        'title': title,
        'note': note,
        'repeat': repeat.code,
        'weekdays': weekdays,
        'hour': hour,
        'minute': minute,
        'date': date,
        'scope': scope.code,
        'enabled': enabled,
        'alarmStyle': alarmStyle,
        'createdAt': createdAt.toIso8601String(),
        'lastFiredAt': lastFiredAt?.toIso8601String(),
      };

  factory ReminderItem.fromJson(Map<String, dynamic> json) => ReminderItem(
        id: json['id'] as String?,
        notifyId: (json['notifyId'] as int?) ?? 0,
        title: (json['title'] as String?) ?? '',
        note: (json['note'] as String?) ?? '',
        repeat: ReminderRepeatX.fromCode((json['repeat'] as int?) ?? 1),
        weekdays: (json['weekdays'] as List<dynamic>?)
                ?.map((e) => e as int)
                .where((e) => e >= 1 && e <= 7)
                .toList() ??
            const [],
        hour: (json['hour'] as int?) ?? 8,
        minute: (json['minute'] as int?) ?? 0,
        date: json['date'] as String?,
        scope: ReminderScopeX.fromCode((json['scope'] as int?) ?? 0),
        enabled: (json['enabled'] as bool?) ?? true,
        alarmStyle: (json['alarmStyle'] as bool?) ?? true,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        lastFiredAt: json['lastFiredAt'] == null
            ? null
            : DateTime.tryParse(json['lastFiredAt'] as String),
      );

  /// 一次性提醒是否已经错过了（日期已过）
  bool isExpired(DateTime now) {
    if (repeat != ReminderRepeat.once || date == null) return false;
    final target = DateTime(
      int.parse(date!.substring(0, 4)),
      int.parse(date!.substring(5, 7)),
      int.parse(date!.substring(8, 10)),
      hour,
      minute,
    );
    return target.isBefore(now);
  }

  /// 下一次响铃的本地时间；不会响则返回 null
  DateTime? nextFireAt(DateTime now) {
    if (!enabled) return null;
    switch (repeat) {
      case ReminderRepeat.once:
        if (date == null) return null;
        final parts = date!.split('-');
        final target = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          hour,
          minute,
        );
        return target.isBefore(now) ? null : target;
      case ReminderRepeat.daily:
        var target =
            DateTime(now.year, now.month, now.day, hour, minute);
        if (!target.isAfter(now)) {
          target = target.add(const Duration(days: 1));
        }
        return target;
      case ReminderRepeat.weekly:
        if (weekdays.isEmpty) return null;
        DateTime? best;
        for (var offset = 0; offset < 8; offset++) {
          final day = now.add(Duration(days: offset));
          if (!weekdays.contains(day.weekday)) continue;
          final candidate =
              DateTime(day.year, day.month, day.day, hour, minute);
          if (candidate.isAfter(now)) {
            best = candidate;
            break;
          }
        }
        return best;
    }
  }
}
