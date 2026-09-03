import 'package:flutter/material.dart';

import '../models/reminder_item.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils_x.dart';
import '../widgets/common.dart';
import '../widgets/reminder_editor_sheet.dart';

/// 提醒页：管理日常闹钟（每天 / 每周）与临时提醒（一次性）
class ReminderPage extends StatefulWidget {
  const ReminderPage({required this.onNavigate, super.key});

  final void Function(int index) onNavigate;

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  Future<void> _add() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('日常提醒'),
              subtitle: const Text('每天或每周固定几天重复'),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('临时提醒'),
              subtitle: const Text('只在指定日期响一次'),
              onTap: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await showReminderEditor(context, initialRoutine: choice);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final theme = Theme.of(context);
    final routine = state.routineReminders;
    final temp = state.tempReminders;
    final isEmpty = routine.isEmpty && temp.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒'),
        actions: [
          IconButton(
            onPressed: () => _showPermissionTip(context),
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: '闹钟不响怎么办',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.alarm_add_rounded),
        label: const Text('新建提醒'),
      ),
      body: isEmpty
          ? Center(
              child: EmptyHint(
                text: '还没有任何提醒\n添加闹钟来掌控你的一天',
                icon: Icons.alarm_off_outlined,
                actionLabel: '新建提醒',
                onAction: _add,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                _Group(
                  title: '日常',
                  subtitle: '每天或每周固定几天',
                  items: routine,
                  icon: Icons.repeat_rounded,
                  onEdit: (item) => showReminderEditor(context, existing: item),
                  onToggle: (item, value) => state.toggleReminder(item.id, value),
                  onDelete: (item) => _delete(context, state, item),
                ),
                _Group(
                  title: '临时',
                  subtitle: '只在指定日期响一次',
                  items: temp,
                  icon: Icons.event_available_outlined,
                  onEdit: (item) => showReminderEditor(context, existing: item),
                  onToggle: (item, value) => state.toggleReminder(item.id, value),
                  onDelete: (item) => _delete(context, state, item),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '侧滑可以删除提醒',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showPermissionTip(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('闹钟不响怎么办'),
        content: const Text(
          '1. 允许应用的通知权限（Android 13 以上会弹窗申请）。\n\n'
          '2. 在系统设置中打开「精确闹钟」权限。\n\n'
          '3. 把「每日罗盘」加入后台运行 / 自启动白名单，'
          '否则国产 ROM 可能会清理掉后台闹钟。\n\n'
          '4. 关闭该应用的省电策略与「睡眠待机优化」。\n\n'
          '可以在主页右上角「设置」里发送测试通知来验证。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    AppState state,
    ReminderItem item,
  ) async {
    await state.removeReminder(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「${item.title}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => state.addReminder(item),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.icon,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final List<ReminderItem> items;
  final IconData icon;
  final void Function(ReminderItem) onEdit;
  final void Function(ReminderItem, bool) onToggle;
  final void Function(ReminderItem) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${items.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
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
                    '暂无$title提醒',
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
                    Dismissible(
                      key: ValueKey(items[i].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                        ),
                      ),
                      confirmDismiss: (_) async {
                        onDelete(items[i]);
                        return true;
                      },
                      child: _ReminderTile(
                        item: items[i],
                        onEdit: () => onEdit(items[i]),
                        onToggle: (value) => onToggle(items[i], value),
                      ),
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

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.item,
    required this.onEdit,
    required this.onToggle,
  });

  final ReminderItem item;
  final VoidCallback onEdit;
  final void Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final expired = item.isExpired(now);
    final next = item.nextFireAt(now);

    final color = item.scope == ReminderScope.work
        ? AppTheme.workColor
        : AppTheme.lifeColor;
    final dimmed = !item.enabled || expired;

    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        onTap: onEdit,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.alarmStyle
                ? Icons.alarm_rounded
                : Icons.notifications_none_rounded,
            color: color,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (expired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('已过期', style: TextStyle(fontSize: 10)),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: formatHm(item.hour, item.minute),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(text: '  ${_whenText(item)}'),
                if (item.note.trim().isNotEmpty)
                  TextSpan(text: '\n${item.note.trim()}'),
                if (next != null)
                  TextSpan(
                    text:
                        '\n下次：${relativeDateLabel(dateKeyOf(next))} ${formatHm(next.hour, next.minute)} · ${countdownText(next)}',
                  ),
              ],
            ),
          ),
        ),
        trailing: Switch(
          value: item.enabled && !expired,
          onChanged: expired ? null : onToggle,
        ),
      ),
    );
  }

  String _whenText(ReminderItem item) {
    switch (item.repeat) {
      case ReminderRepeat.once:
        return '${item.scope.label} · ${relativeDateLabel(item.date ?? '')}';
      case ReminderRepeat.daily:
        return '${item.scope.label} · 每天';
      case ReminderRepeat.weekly:
        return '${item.scope.label} · ${weekdaysText(item.weekdays)}';
    }
  }
}
