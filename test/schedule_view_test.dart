import 'package:daily_compass/models/memo_item.dart';
import 'package:daily_compass/models/reminder_item.dart';
import 'package:daily_compass/utils/date_utils_x.dart';
import 'package:daily_compass/widgets/daily_schedule_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证日程表视图能根据示例数据渲染出对应的条目与时段。
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
    await tester.pumpAndSettle();

    // 每天的上午/下午/晚上三个时段都会渲染（2 天 -> 6 个时段标签）
    expect(find.text('上午'), findsWidgets);
    expect(find.text('下午'), findsWidgets);
    expect(find.text('晚上'), findsWidgets);

    // 备忘各出现一次；提醒是“每天”重复，所以每天都会出现，至少一次。
    for (final title in [
      '去协和医院',
      '处理OA',
      '福建开放大学审稿',
      '看计算机学报论文',
      '填写研究生登记表',
      '审批文件',
      '看电影',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('部门晨会'), findsWidgets);
  });
}
