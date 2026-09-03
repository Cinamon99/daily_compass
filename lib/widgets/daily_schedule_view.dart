import 'package:flutter/material.dart';

import '../models/memo_item.dart';
import '../models/reminder_item.dart';
import '../utils/date_utils_x.dart';
import '../utils/schedule_utils.dart';

/// 每日任务安排表视图：根据备忘和提醒自动生成。
class DailyScheduleView extends StatelessWidget {
  const DailyScheduleView({
    required this.memos,
    required this.reminders,
    this.days = 7,
    super.key,
  });

  final List<MemoItem> memos;
  final List<ReminderItem> reminders;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = buildDailySchedule(
      memos: memos,
      reminders: reminders,
      days: days,
    );

    if (schedule.every((d) => d.morning.isEmpty && d.afternoon.isEmpty && d.evening.isEmpty)) {
      return _EmptySchedule(theme: theme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '每日任务安排表',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '根据备忘和提醒自动生成 · 显示最近 $days 天',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: _buildTable(context, schedule),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<DailySchedule> schedule) {
    final theme = Theme.of(context);
    return Table(
      border: TableBorder.all(
        color: theme.dividerColor.withValues(alpha: 0.5),
        width: 1,
      ),
      columnWidths: const {
        0: FixedColumnWidth(70),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        _headerRow(context),
        for (final day in schedule) _dayRow(context, day),
      ],
    );
  }

  TableRow _headerRow(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurface,
    );
    return TableRow(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      children: [
        _cell('日期', style: headerStyle, center: true),
        _cell('上午', style: headerStyle, center: true),
        _cell('下午', style: headerStyle, center: true),
        _cell('晚上', style: headerStyle, center: true),
      ],
    );
  }

  TableRow _dayRow(BuildContext context, DailySchedule day) {
    final theme = Theme.of(context);
    final isToday = day.dateKey == todayKey();
    final dateText = '${day.date.month}.${day.date.day}';
    final weekdayText = '周${weekdayShort[day.date.weekday]}';

    return TableRow(
      children: [
        _cell(
          dateText,
          subtitle: weekdayText,
          center: true,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isToday ? theme.colorScheme.primary : null,
          ),
        ),
        _periodCell(context, day.morning),
        _periodCell(context, day.afternoon),
        _periodCell(context, day.evening),
      ],
    );
  }

  Widget _periodCell(BuildContext context, List<ScheduleEvent> events) {
    final theme = Theme.of(context);
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        alignment: Alignment.topLeft,
        child: Text(
          '-',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < events.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}、',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      events[i].title,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(
    String text, {
    String? subtitle,
    TextStyle? style,
    bool center = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      alignment: center ? Alignment.center : Alignment.topLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: style),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: style?.color?.withValues(alpha: 0.7) ??
                    Colors.grey,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '最近 7 天没有安排',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '在备忘页添加带日期的备忘，\n或在提醒页设置闹钟后会自动生成安排表',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
