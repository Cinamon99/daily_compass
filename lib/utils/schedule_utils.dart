import 'package:flutter/material.dart';

import '../models/memo_item.dart';
import '../models/reminder_item.dart';
import 'date_utils_x.dart';

/// 一天中的时段
enum DayPeriod { morning, afternoon, evening }

extension DayPeriodX on DayPeriod {
  String get label {
    switch (this) {
      case DayPeriod.morning:
        return '上午';
      case DayPeriod.afternoon:
        return '下午';
      case DayPeriod.evening:
        return '晚上';
    }
  }
}

/// 日程表中的一个事件
class ScheduleEvent {
  final String title;
  final String sourceLabel; // 例如 "提醒·工作" / "备忘·生活"
  final String? timeText; // 09:30
  final Color? color;
  final String? memoId;
  final String? reminderId;

  const ScheduleEvent({
    required this.title,
    required this.sourceLabel,
    this.timeText,
    this.color,
    this.memoId,
    this.reminderId,
  });
}

/// 某一天的完整日程
class DailySchedule {
  final String dateKey;
  final DateTime date;
  final List<ScheduleEvent> morning;
  final List<ScheduleEvent> afternoon;
  final List<ScheduleEvent> evening;

  const DailySchedule({
    required this.dateKey,
    required this.date,
    required this.morning,
    required this.afternoon,
    required this.evening,
  });

  List<ScheduleEvent> eventsFor(DayPeriod period) {
    switch (period) {
      case DayPeriod.morning:
        return morning;
      case DayPeriod.afternoon:
        return afternoon;
      case DayPeriod.evening:
        return evening;
    }
  }
}

DayPeriod _periodOf(int hour) {
  if (hour < 12) return DayPeriod.morning;
  if (hour < 18) return DayPeriod.afternoon;
  return DayPeriod.evening;
}

String _formatHm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// 根据备忘和提醒自动生成未来 [days] 天的每日任务安排表。
///
/// - 提醒按实际时间进入对应时段。
/// - 备忘没有具体时间，会按“负载均衡”自动填入当前事件最少的时段
///   （上午/下午/晚上），并在该时段内按默认时间排序。
List<DailySchedule> buildDailySchedule({
  required List<MemoItem> memos,
  required List<ReminderItem> reminders,
  DateTime? start,
  int days = 7,
}) {
  final startDate = start ?? DateTime.now();
  final result = <DailySchedule>[];

  for (var i = 0; i < days; i++) {
    final date = startDate.add(Duration(days: i));
    final key = dateKeyOf(date);
    final weekday = date.weekday;

    final morning = <ScheduleEvent>[];
    final afternoon = <ScheduleEvent>[];
    final evening = <ScheduleEvent>[];

    void addToPeriod(DayPeriod period, ScheduleEvent event) {
      switch (period) {
        case DayPeriod.morning:
          morning.add(event);
          break;
        case DayPeriod.afternoon:
          afternoon.add(event);
          break;
        case DayPeriod.evening:
          evening.add(event);
          break;
      }
    }

    // 1. 先放提醒（有明确时间）
    for (final r in reminders) {
      if (!r.enabled) continue;
      bool match = false;
      switch (r.repeat) {
        case ReminderRepeat.once:
          match = r.date == key;
          break;
        case ReminderRepeat.daily:
          match = true;
          break;
        case ReminderRepeat.weekly:
          match = r.weekdays.contains(weekday);
          break;
      }
      if (!match) continue;

      final period = _periodOf(r.hour);
      addToPeriod(
        period,
        ScheduleEvent(
          title: r.title,
          sourceLabel: '提醒·${r.scope.label}',
          timeText: _formatHm(r.hour, r.minute),
          reminderId: r.id,
        ),
      );
    }

    // 2. 再放入备忘（仅未完成的）
    // 按优先级降序，同优先级下按创建时间升序
    final dayMemos = memos
        .where((m) => !m.done && m.planDate == key)
        .toList()
      ..sort((a, b) {
        final p = b.priority.index.compareTo(a.priority.index);
        if (p != 0) return p;
        return a.createdAt.compareTo(b.createdAt);
      });

    for (final m in dayMemos) {
      // 负载均衡：选事件最少的时段；相同时优先上午→下午→晚上
      final counts = {
        DayPeriod.morning: morning.length,
        DayPeriod.afternoon: afternoon.length,
        DayPeriod.evening: evening.length,
      };
      final minCount = counts.values.reduce((a, b) => a < b ? a : b);
      DayPeriod chosen = DayPeriod.morning;
      for (final p in DayPeriod.values) {
        if (counts[p] == minCount) {
          chosen = p;
          break;
        }
      }

      final defaultHour = switch (chosen) {
        DayPeriod.morning => 9,
        DayPeriod.afternoon => 14,
        DayPeriod.evening => 19,
      };

      addToPeriod(
        chosen,
        ScheduleEvent(
          title: m.title,
          sourceLabel: '备忘·${m.category.label}',
          timeText: _formatHm(defaultHour, 0),
          color: m.category == MemoCategory.work
              ? Colors.blueAccent
              : Colors.orangeAccent,
          memoId: m.id,
        ),
      );
    }

    int sortByTime(ScheduleEvent a, ScheduleEvent b) {
      return (a.timeText ?? '00:00').compareTo(b.timeText ?? '00:00');
    }

    morning.sort(sortByTime);
    afternoon.sort(sortByTime);
    evening.sort(sortByTime);

    result.add(
      DailySchedule(
        dateKey: key,
        date: date,
        morning: morning,
        afternoon: afternoon,
        evening: evening,
      ),
    );
  }

  return result;
}
