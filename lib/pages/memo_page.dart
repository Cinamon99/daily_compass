import 'package:flutter/material.dart';

import '../models/memo_item.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import '../utils/date_utils_x.dart';
import '../utils/schedule_utils.dart';
import '../services/export_service.dart';
import '../widgets/common.dart';
import '../widgets/daily_schedule_view.dart';
import '../widgets/memo_editor_sheet.dart';

/// 备忘页：按「生活 / 工作」分类管理备忘与待办
class MemoPage extends StatefulWidget {
  const MemoPage({required this.onNavigate, super.key});

  final void Function(int index) onNavigate;

  @override
  State<MemoPage> createState() => _MemoPageState();
}

enum _MemoView { list, schedule }

class _MemoPageState extends State<MemoPage> {
  MemoCategory _category = MemoCategory.life;
  _MemoView _view = _MemoView.list;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final theme = Theme.of(context);
    final items = state.memosOf(_category);
    final today = todayKey();

    final overdue = items
        .where((e) => !e.done && e.planDate != null && e.planDate!.compareTo(today) < 0)
        .toList();
    final todayList =
        items.where((e) => !e.done && e.planDate == today).toList();
    final unplanned = items.where((e) => !e.done && e.planDate == null).toList();
    final done = items.where((e) => e.done).toList()
      ..sort((a, b) => (b.completedAt ?? b.createdAt)
          .compareTo(a.completedAt ?? a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('备忘'),
        actions: [
          if (_view == _MemoView.schedule)
            IconButton(
              onPressed: () => _exportSchedule(context, state),
              icon: const Icon(Icons.download_outlined),
              tooltip: '导出日程表',
            ),
          if (_view == _MemoView.list && done.isNotEmpty)
            IconButton(
              onPressed: () => state.clearCompletedMemos(_category),
              icon: const Icon(Icons.cleaning_services_outlined),
              tooltip: '清除已完成',
            ),
        ],
      ),
      floatingActionButton: _view == _MemoView.list
          ? FloatingActionButton.extended(
              onPressed: () => showMemoEditor(context, initialCategory: _category),
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建备忘'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<_MemoView>(
              segments: const [
                ButtonSegment(
                  value: _MemoView.list,
                  label: Text('备忘'),
                  icon: Icon(Icons.list_alt_outlined),
                ),
                ButtonSegment(
                  value: _MemoView.schedule,
                  label: Text('日程表'),
                  icon: Icon(Icons.calendar_month_outlined),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (value) =>
                  setState(() => _view = value.first),
              style: ButtonStyle(
                minimumSize: WidgetStateProperty.all(
                  const Size.fromHeight(44),
                ),
              ),
            ),
          ),
          if (_view == _MemoView.list)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SegmentedButton<MemoCategory>(
                segments: const [
                  ButtonSegment(
                    value: MemoCategory.life,
                    label: Text('生活'),
                    icon: Icon(Icons.home_outlined),
                  ),
                  ButtonSegment(
                    value: MemoCategory.work,
                    label: Text('工作'),
                    icon: Icon(Icons.work_outline),
                  ),
                ],
                selected: {_category},
                onSelectionChanged: (value) =>
                    setState(() => _category = value.first),
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(
                    const Size.fromHeight(40),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _view == _MemoView.list
                ? (items.isEmpty
                    ? Center(
                        child: EmptyHint(
                          text: '还没有${_category.label}备忘\n点击右下角按钮添加第一条',
                          icon: Icons.note_add_outlined,
                          actionLabel: '新建备忘',
                          onAction: () => showMemoEditor(
                            context,
                            initialCategory: _category,
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        children: [
                          _Section(
                            title: '逾期未完成',
                            items: overdue,
                            emptyText: null,
                            highlight: true,
                            onEdit: (memo) => showMemoEditor(context, existing: memo),
                            onToggle: (memo, value) =>
                                state.toggleMemoDone(memo.id, value),
                            onDelete: (memo) => _delete(context, state, memo),
                          ),
                          _Section(
                            title: '今天',
                            items: todayList,
                            emptyText: '今天没有安排，要不要加一条？',
                            onEdit: (memo) => showMemoEditor(context, existing: memo),
                            onToggle: (memo, value) =>
                                state.toggleMemoDone(memo.id, value),
                            onDelete: (memo) => _delete(context, state, memo),
                          ),
                          _Section(
                            title: '待安排',
                            items: unplanned,
                            emptyText: null,
                            onEdit: (memo) => showMemoEditor(context, existing: memo),
                            onToggle: (memo, value) =>
                                state.toggleMemoDone(memo.id, value),
                            onDelete: (memo) => _delete(context, state, memo),
                          ),
                          _Section(
                            title: '已完成',
                            items: done,
                            emptyText: null,
                            onEdit: (memo) => showMemoEditor(context, existing: memo),
                            onToggle: (memo, value) =>
                                state.toggleMemoDone(memo.id, value),
                            onDelete: (memo) => _delete(context, state, memo),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              '长按或侧滑可以删除备忘',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ))
                : DailyScheduleView(
                    memos: state.memos,
                    reminders: state.reminders,
                    days: 7,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    AppState state,
    MemoItem memo,
  ) async {
    await state.removeMemo(memo.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「${memo.title}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => state.addMemo(memo),
        ),
      ),
    );
  }

  Future<void> _exportSchedule(BuildContext context, AppState state) async {
    final message = await ExportService.runExport(
      context,
      title: '导出每日任务安排表',
      build: (format) => ExportService.instance.exportSchedule(
        buildDailySchedule(
          memos: state.memos,
          reminders: state.reminders,
          days: 7,
        ),
        format,
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.emptyText,
    this.highlight = false,
  });

  final String title;
  final List<MemoItem> items;
  final void Function(MemoItem) onEdit;
  final void Function(MemoItem, bool) onToggle;
  final void Function(MemoItem) onDelete;
  final String? emptyText;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty && emptyText == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: highlight
                        ? Colors.redAccent
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${items.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Center(
                  child: Text(
                    emptyText ?? '暂无',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: theme.dividerColor.withValues(alpha: 0.4),
                      ),
                    _MemoTile(
                      memo: items[i],
                      onEdit: () => onEdit(items[i]),
                      onToggle: (value) => onToggle(items[i], value),
                      onDelete: () => onDelete(items[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MemoTile extends StatelessWidget {
  const _MemoTile({
    required this.memo,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final MemoItem memo;
  final VoidCallback onEdit;
  final void Function(bool) onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = !memo.done &&
        memo.planDate != null &&
        memo.planDate!.compareTo(todayKey()) < 0;

    return Dismissible(
      key: ValueKey(memo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return true;
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Checkbox(
          value: memo.done,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          onChanged: (value) => onToggle(value ?? false),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                memo.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: memo.done ? TextDecoration.lineThrough : null,
                  color: memo.done ? theme.colorScheme.onSurfaceVariant : null,
                ),
              ),
            ),
            if (memo.priority != MemoPriority.normal)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: PriorityChip(priority: memo.priority),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (memo.note.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  memo.note.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (memo.planDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? Colors.redAccent.withValues(alpha: 0.14)
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      relativeDateLabel(memo.planDate!),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isOverdue
                            ? Colors.redAccent
                            : theme.colorScheme.primary,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '未排期',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  '${memo.createdAt.month}/${memo.createdAt.day} 创建',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
