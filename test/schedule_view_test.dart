import 'package:daily_compass/models/memo_item.dart';
import 'package:daily_compass/models/reminder_item.dart';
import 'package:daily_compass/utils/date_utils_x.dart';
import 'package:daily_compass/widgets/daily_schedule_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 这个测试主要用于生成日程表视图的 golden 截图，
/// 方便在无法实机输入数据时验证 UI 效果。
void main() {
  testWidgets('日程表视图与示例数据一致', (tester) async {
    final today = dateKeyOf(DateTime.now());

    final memos = [
      MemoItem(
        title: '去协和医院',
        category: MemoCategory.life,
        planDate: today,
      ),
      MemoItem(
        title: '处理OA',
        category: MemoCategory.work,
        planDate: today,
      ),
      MemoItem(
        title: '福建开放大学审稿',
        category: MemoCategory.work,
        priority: MemoPriority.important,
        planDate: today,
      ),
      MemoItem(
        title: '看计算机学报论文',
        category: MemoCategory.work,
        planDate: today,
      ),
      MemoItem(
        title: '填写研究生登记表',
        category: MemoCategory.work,
        planDate: today,
      ),
      MemoItem(
        title: '审批文件',
        category: MemoCategory.work,
        priority: MemoPriority.urgent,
        planDate: today,
      ),
      MemoItem(
        title: '看电影',
        category: MemoCategory.life,
        planDate: today,
      ),
    ];

    final reminders = [
      ReminderItem(
        notifyId: 10,
        title: '部门晨会',
        hour: 9,
        minute: 0,
        repeat: ReminderRepeat.daily,
        scope: ReminderScope.work,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyScheduleView(
            memos: memos,
            reminders: reminders,
            days: 2,
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(DailyScheduleView),
      matchesGoldenFile('schedule_view.png'),
    );
  });
}
