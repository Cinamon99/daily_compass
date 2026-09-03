import 'dart:async';

import 'package:flutter/material.dart';

import '../models/daily_review.dart';
import '../models/memo_item.dart';
import '../models/reminder_item.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils_x.dart';
import '../widgets/common.dart';
import '../widgets/memo_editor_sheet.dart';
import '../widgets/reminder_editor_sheet.dart';
import '../widgets/settings_sheet.dart';

/// 主页：一屏概览时间、今日进度、提醒、生活与工作备忘、今日总结状态
class HomePage extends StatefulWidget {
  const HomePage({required this.onNavigate, super.key});

  final void Function(int index) onNavigate;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = _now.hour;
    if (hour < 5) return '夜深了';
    if (hour < 9) return '早上好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    if (hour < 23) return '晚上好';
    return '夜深了';
  }

  String get _dateText =>
      '${_now.year}年${_now.month}月${_now.day}日  星期${weekdayShort[_now.weekday]}';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => state.reschedule(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Header(
              greeting: _greeting,
              now: _now,
              dateText: _dateText,
              onSettings: () => showSettingsSheet(context),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _QuickActions(
                    onAddMemo: () => showMemoEditor(context),
                    onAddReminder: () => showReminderEditor(context),
                    onWriteReview: () => widget.onNavigate(3),
                  ),
                  const SizedBox(height: 16),
                  _ProgressCard(state: state),
                  const SizedBox(height: 16),
                  _ReminderCard(
                    state: state,
                    now: _now,
                    onViewAll: () => widget.onNavigate(2),
                  ),
                  const SizedBox(height: 16),
                  _MemoBriefCard(
                    state: state,
                    category: MemoCategory.life,
                    onViewAll: () => widget.onNavigate(1),
                  ),
                  const SizedBox(height: 16),
                  _MemoBriefCard(
                    state: state,
                    category: MemoCategory.work,
                    onViewAll: () => widget.onNavigate(1),
                  ),
                  const SizedBox(height: 16),
                  _ReviewCard(
                    state: state,
                    onWrite: () => widget.onNavigate(3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 顶部时间

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.now,
    required this.dateText,
    required this.onSettings,
  });

  final String greeting;
  final DateTime now;
  final String dateText;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 28,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.16),
            scheme.primary.withValues(alpha: 0.03),
            scheme.surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onSettings,
                icon: const Icon(Icons.settings_outlined),
                tooltip: '设置',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ':${now.second.toString().padLeft(2, '0')}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 快捷操作

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddMemo,
    required this.onAddReminder,
    required this.onWriteReview,
  });

  final VoidCallback onAddMemo;
  final VoidCallback onAddReminder;
  final VoidCallback onWriteReview;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickButton(
            icon: Icons.add_task_rounded,
            label: '加备忘',
            color: AppTheme.lifeColor,
            onTap: onAddMemo,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickButton(
            icon: Icons.alarm_add_rounded,
            label: '加提醒',
            color: AppTheme.accentColor,
            onTap: onAddReminder,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickButton(
            icon: Icons.edit_note_rounded,
            label: '写总结',
            color: AppTheme.workColor,
            onTap: onWriteReview,
          ),
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 今日进度

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = state.todayMemos;
    final doneCount = today.where((e) => e.done).length;
    final progress = state.todayProgress;
    final overdue = state.overdueMemos.length;

    final life = today.where((e) => e.category == MemoCategory.life);
    final work = today.where((e) => e.category == MemoCategory.work);

    return SectionCard(
      title: '今日进度',
      icon: Icons.track_changes_rounded,
      trailing: overdue > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$overdue 项逾期',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress * 100).round()}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  today.isEmpty
                      ? '今天还没有安排任务'
                      : '已完成 $doneCount / ${today.length} 项',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _ProgressLine(
                  label: '生活',
                  color: AppTheme.lifeColor,
                  done: life.where((e) => e.done).length,
                  total: life.length,
                ),
                const SizedBox(height: 6),
                _ProgressLine(
                  label: '工作',
                  color: AppTheme.workColor,
                  done: work.where((e) => e.done).length,
                  total: work.length,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.color,
    required this.done,
    required this.total,
  });

  final String label;
  final Color color;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = total == 0 ? 0.0 : done / total;
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            '$done/$total',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 提醒简览

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.state,
    required this.now,
    required this.onViewAll,
  });

  final AppState state;
  final DateTime now;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = state.nextReminder;
    final upcoming = state.upcomingReminders(limit: 3);

    return SectionCard(
      title: '提醒',
      icon: Icons.alarm_rounded,
      accentColor: AppTheme.accentColor,
      trailing: TextButton(
        onPressed: onViewAll,
        child: const Text('全部'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (next == null)
            const EmptyHint(
              text: '还没有启用的提醒，去「提醒」页添加一个闹钟吧',
              icon: Icons.alarm_off_outlined,
              compact: true,
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      next.item.alarmStyle
                          ? Icons.alarm_rounded
                          : Icons.notifications_rounded,
                      color: AppTheme.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          next.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_whenText(next.item)} · ${relativeDateLabel(dateKeyOf(next.at))} ${formatHm(next.at.hour, next.at.minute)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    countdownText(next.at),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (upcoming.length > 1) ...[
              const SizedBox(height: 10),
              ...upcoming.skip(1).map(
                    (item) => _ReminderRow(item: item, now: now),
                  ),
            ],
          ],
        ],
      ),
    );
  }

  String _whenText(ReminderItem item) {
    switch (item.repeat) {
      case ReminderRepeat.once:
        return '临时';
      case ReminderRepeat.daily:
        return '每天';
      case ReminderRepeat.weekly:
        return weekdaysText(item.weekdays);
    }
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.item, required this.now});

  final ReminderItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = item.nextFireAt(now);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            item.alarmStyle
                ? Icons.alarm_rounded
                : Icons.notifications_none_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            at == null ? '—' : '${relativeDateLabel(dateKeyOf(at))} ${formatHm(at.hour, at.minute)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 备忘简览

class _MemoBriefCard extends StatelessWidget {
  const _MemoBriefCard({
    required this.state,
    required this.category,
    required this.onViewAll,
  });

  final AppState state;
  final MemoCategory category;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final today = todayKey();
    final all = state.memosOf(category).where((e) {
      // 只展示今天排期、逾期未完成、以及今天刚完成的
      if (e.done) return e.planDate == today || e.completedAt == null;
      return e.planDate == null || e.planDate!.compareTo(today) <= 0;
    }).toList();

    all.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final pa = (a.planDate ?? '9999-99-99');
      final pb = (b.planDate ?? '9999-99-99');
      if (pa != pb) return pa.compareTo(pb);
      return b.priority.index.compareTo(a.priority.index);
    });

    final shown = all.take(3).toList();
    final remaining = all.length - shown.length;

    return SectionCard(
      title: '${category.label}备忘',
      icon: category == MemoCategory.work
          ? Icons.work_outline
          : Icons.home_outlined,
      accentColor:
          category == MemoCategory.work ? AppTheme.workColor : AppTheme.lifeColor,
      trailing: TextButton(onPressed: onViewAll, child: const Text('全部')),
      child: shown.isEmpty
          ? EmptyHint(
              text: '暂无${category.label}备忘',
              icon: category == MemoCategory.work
                  ? Icons.work_off_outlined
                  : Icons.weekend_outlined,
              compact: true,
            )
          : Column(
              children: [
                ...shown.map(
                  (memo) => _MemoBriefRow(
                    memo: memo,
                    color: category == MemoCategory.work
                        ? AppTheme.workColor
                        : AppTheme.lifeColor,
                  ),
                ),
                if (remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '还有 $remaining 项…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MemoBriefRow extends StatelessWidget {
  const _MemoBriefRow({required this.memo, required this.color});

  final MemoItem memo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = AppStateScope.read(context);
    final isOverdue =
        !memo.done && memo.planDate != null && memo.planDate!.compareTo(todayKey()) < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: memo.done,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              onChanged: (value) =>
                  state.toggleMemoDone(memo.id, value ?? false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              memo.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: memo.done ? TextDecoration.lineThrough : null,
                color: memo.done ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
          if (memo.priority != MemoPriority.normal)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PriorityChip(priority: memo.priority),
            ),
          if (isOverdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                memo.planDate == null ? '' : '逾期',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 总结入口

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.state, required this.onWrite});

  final AppState state;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = state.reviewOf(todayKey());
    final streak = state.reviewStreak;
    final avg = state.averageScore;

    return SectionCard(
      title: '今日总结',
      icon: Icons.auto_stories_rounded,
      accentColor: AppTheme.workColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (today == null || today.isEmpty) ...[
            Text(
              '今天还没有写总结，花三分钟回顾一下吧。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onWrite,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('写今天的总结'),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${today.score} 分',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    scoreComment(today.score),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (today.summary.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                today.summary.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onWrite,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('继续补充'),
              ),
            ),
          ],
          if (streak > 0 || avg > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '连续记录 $streak 天',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '平均 ${avg.toStringAsFixed(1)} 分',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
