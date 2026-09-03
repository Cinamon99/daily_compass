import 'package:flutter_test/flutter_test.dart';

import 'package:daily_compass/models/daily_review.dart';
import 'package:daily_compass/models/memo_item.dart';
import 'package:daily_compass/models/reminder_item.dart';
import 'package:daily_compass/services/notification_service.dart';
import 'package:daily_compass/utils/date_utils_x.dart';

void main() {
  group('日期工具', () {
    test('日期键格式为 yyyy-MM-dd 且可往返解析', () {
      final d = DateTime(2026, 8, 30, 17, 26);
      expect(dateKeyOf(d), '2026-08-30');
      // 解析回来只保留到天，时分秒归零
      expect(parseDateKey(dateKeyOf(d)), DateTime(2026, 8, 30));
      expect(dateKeyOf(parseDateKey('2026-08-30')), '2026-08-30');
    });

    test('星期文本', () {
      expect(weekdayLabel(DateTime.monday), '周一');
      expect(weekdayLabel(DateTime.sunday), '周日');
      expect(weekdaysText([1, 3, 5]), '周一、周三、周五');
      expect(weekdaysText([1, 2, 3, 4, 5, 6, 7]), '每天');
    });

    test('时间格式化', () {
      expect(formatHm(8, 5), '08:05');
      expect(formatHm(21, 30), '21:30');
    });

    test('相对日期标签', () {
      final today = todayKey();
      expect(relativeDateLabel(today), '今天');
      expect(relativeDateLabel(''), '');
    });

    test('倒计时文本', () {
      // 倒计时按分钟截断，多给几秒避免边界抖动
      final future = DateTime.now().add(
        const Duration(hours: 2, minutes: 15, seconds: 5),
      );
      expect(countdownText(future), '2小时15分后');
      expect(
        countdownText(DateTime.now().subtract(const Duration(minutes: 1))),
        '已过期',
      );
    });
  });

  group('提醒的下一次触发时间', () {
    ReminderItem base({
      ReminderRepeat repeat = ReminderRepeat.daily,
      List<int> weekdays = const [],
      int hour = 8,
      int minute = 0,
      String? date,
    }) =>
        ReminderItem(
          notifyId: 10,
          title: '测试',
          repeat: repeat,
          weekdays: weekdays,
          hour: hour,
          minute: minute,
          date: date,
        );

    test('每天：今天时间未到则今天，已过则明天', () {
      final now = DateTime(2026, 8, 30, 10, 0);
      final later = base(hour: 15, minute: 30).nextFireAt(now);
      expect(later, DateTime(2026, 8, 30, 15, 30));

      final earlier = base(hour: 7, minute: 0).nextFireAt(now);
      expect(earlier, DateTime(2026, 8, 31, 7, 0));
    });

    test('每周：跳到下一个匹配的星期', () {
      // 2026-08-30 是周日（weekday = 7）
      final now = DateTime(2026, 8, 30, 10, 0);
      expect(now.weekday, DateTime.sunday);

      // 只在周一提醒 -> 下一次是 2026-08-31
      final monday = base(repeat: ReminderRepeat.weekly, weekdays: [1]);
      expect(monday.nextFireAt(now), DateTime(2026, 8, 31, 8, 0));

      // 周日也提醒，但今天 8:00 已过 -> 下一次是下周日
      final sunday = base(repeat: ReminderRepeat.weekly, weekdays: [7]);
      expect(sunday.nextFireAt(now), DateTime(2026, 9, 6, 8, 0));

      // 周日提醒且时间还没到 -> 今天
      final sundayLater = base(
        repeat: ReminderRepeat.weekly,
        weekdays: [7],
        hour: 20,
      );
      expect(sundayLater.nextFireAt(now), DateTime(2026, 8, 30, 20, 0));
    });

    test('临时：到点前返回当天，过期返回 null', () {
      final now = DateTime(2026, 8, 30, 10, 0);
      final pending = base(
        repeat: ReminderRepeat.once,
        date: '2026-08-30',
        hour: 18,
        minute: 30,
      );
      expect(pending.nextFireAt(now), DateTime(2026, 8, 30, 18, 30));

      final expired = base(
        repeat: ReminderRepeat.once,
        date: '2026-08-30',
        hour: 8,
      );
      expect(expired.nextFireAt(now), isNull);
      expect(expired.isExpired(now), isTrue);
    });

    test('停用后不再触发', () {
      final item = base()..enabled = false;
      expect(item.nextFireAt(DateTime(2026, 8, 30, 10, 0)), isNull);
    });
  });

  group('通知 ID 分配', () {
    test('每周提醒的派生 ID 不会与一次性/每天提醒冲突', () {
      final used = <int>{};
      for (var notifyId = 10; notifyId < 500; notifyId++) {
        expect(used.add(notifyId), isTrue);
        for (var wd = 1; wd <= 7; wd++) {
          expect(used.add(NotificationService.weeklyId(notifyId, wd)), isTrue);
        }
      }
      // 内置提醒占用的 ID 也不能被占用
      expect(used.contains(NotificationService.morningNotifyId), isFalse);
      expect(used.contains(NotificationService.summaryNotifyId), isFalse);
    });
  });

  group('序列化往返', () {
    test('备忘', () {
      final memo = MemoItem(
        title: '买牛奶',
        note: '顺便取快递',
        category: MemoCategory.life,
        priority: MemoPriority.urgent,
        planDate: '2026-08-30',
      );
      final restored = MemoItem.fromJson(memo.toJson());
      expect(restored.id, memo.id);
      expect(restored.title, '买牛奶');
      expect(restored.note, '顺便取快递');
      expect(restored.category, MemoCategory.life);
      expect(restored.priority, MemoPriority.urgent);
      expect(restored.planDate, '2026-08-30');
      expect(restored.done, isFalse);
    });

    test('提醒', () {
      final item = ReminderItem(
        notifyId: 42,
        title: '周会',
        note: '带上进度表',
        repeat: ReminderRepeat.weekly,
        weekdays: [1, 3, 5],
        hour: 9,
        minute: 30,
        scope: ReminderScope.work,
        alarmStyle: false,
      );
      final restored = ReminderItem.fromJson(item.toJson());
      expect(restored.notifyId, 42);
      expect(restored.title, '周会');
      expect(restored.repeat, ReminderRepeat.weekly);
      expect(restored.weekdays, [1, 3, 5]);
      expect(restored.hour, 9);
      expect(restored.minute, 30);
      expect(restored.scope, ReminderScope.work);
      expect(restored.alarmStyle, isFalse);
      expect(restored.isRoutine, isTrue);
    });

    test('总结', () {
      final review = DailyReview(
        dateKey: '2026-08-30',
        summary: '完成了三个需求',
        reflection: '会议太多，要留出整块时间',
        score: 8,
        mood: 4,
      );
      final restored = DailyReview.fromJson(review.toJson());
      expect(restored.dateKey, '2026-08-30');
      expect(restored.summary, '完成了三个需求');
      expect(restored.reflection, '会议太多，要留出整块时间');
      expect(restored.score, 8);
      expect(restored.mood, 4);
      expect(restored.isEmpty, isFalse);
    });

    test('损坏的 JSON 不会让模型崩溃', () {
      final memo = MemoItem.fromJson(<String, dynamic>{});
      expect(memo.title, '');
      expect(memo.done, isFalse);
    });
  });
}
