import 'package:flutter/material.dart';

import '../models/reminder_item.dart';
import '../state/app_state_scope.dart';
import '../utils/date_utils_x.dart';
import 'common.dart';

/// 打开提醒 / 闹钟编辑弹层，返回 true 表示已保存。
Future<bool> showReminderEditor(
  BuildContext context, {
  ReminderItem? existing,
  bool initialRoutine = true,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReminderEditorSheet(
      existing: existing,
      initialRoutine: initialRoutine,
    ),
  );
  return result ?? false;
}

class _ReminderEditorSheet extends StatefulWidget {
  const _ReminderEditorSheet({this.existing, this.initialRoutine = true});

  final ReminderItem? existing;
  final bool initialRoutine;

  @override
  State<_ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<_ReminderEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;

  late bool _isRoutine;
  late ReminderRepeat _repeat;
  late List<int> _weekdays;
  late TimeOfDay _time;
  late String _date;
  late ReminderScope _scope;
  late bool _alarmStyle;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _isRoutine = existing?.isRoutine ?? widget.initialRoutine;
    _repeat = existing?.repeat ??
        (widget.initialRoutine ? ReminderRepeat.daily : ReminderRepeat.once);
    _weekdays = [...(existing?.weekdays ?? [DateTime.now().weekday])];
    _time = TimeOfDay(
      hour: existing?.hour ?? 8,
      minute: existing?.minute ?? 0,
    );
    _date = existing?.date ?? todayKey();
    _scope = existing?.scope ?? ReminderScope.life;
    _alarmStyle = existing?.alarmStyle ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '选择提醒时间',
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = parseDateKey(_date);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(now.year, now.month, now.day))
          ? now
          : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      helpText: '选择提醒日期',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = dateKeyOf(picked));
  }

  String get _summaryText {
    final timeText = formatHm(_time.hour, _time.minute);
    if (!_isRoutine) {
      return '${relativeDateLabel(_date)} $timeText 响一次';
    }
    if (_repeat == ReminderRepeat.daily) {
      return '每天 $timeText';
    }
    if (_weekdays.isEmpty) return '请选择提醒的星期';
    return '${weekdaysText(_weekdays)} 的 $timeText';
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写提醒内容')));
      return;
    }
    if (_isRoutine &&
        _repeat == ReminderRepeat.weekly &&
        _weekdays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一个星期')));
      return;
    }

    final state = AppStateScope.read(context);
    final existing = widget.existing;

    if (existing == null) {
      final notifyId = await state.allocateNotifyId();
      await state.addReminder(
        ReminderItem(
          notifyId: notifyId,
          title: title,
          note: _note.text.trim(),
          repeat: _isRoutine ? _repeat : ReminderRepeat.once,
          weekdays: _isRoutine && _repeat == ReminderRepeat.weekly
              ? _weekdays
              : const [],
          hour: _time.hour,
          minute: _time.minute,
          date: _isRoutine ? null : _date,
          scope: _scope,
          alarmStyle: _alarmStyle,
        ),
      );
    } else {
      existing.title = title;
      existing.note = _note.text.trim();
      existing.repeat = _isRoutine ? _repeat : ReminderRepeat.once;
      existing.weekdays =
          _isRoutine && _repeat == ReminderRepeat.weekly ? _weekdays : const [];
      existing.hour = _time.hour;
      existing.minute = _time.minute;
      existing.date = _isRoutine ? null : _date;
      existing.scope = _scope;
      existing.alarmStyle = _alarmStyle;
      await state.updateReminder(existing);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除提醒'),
        content: const Text('删除后对应的闹钟也会一并取消，确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppStateScope.read(context).removeReminder(existing.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;

    return SheetContainer(
      title: isEditing ? '编辑提醒' : '新建提醒',
      subtitle: _summaryText,
      footer: SheetActions(
        onSave: _save,
        onDelete: isEditing ? _delete : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            autofocus: !isEditing,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: '提醒我做什么？',
              prefixIcon: Icon(Icons.notifications_active_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: '备注（可选）',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 18),

          Text('类型', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('日常'),
                icon: Icon(Icons.repeat_rounded),
              ),
              ButtonSegment(
                value: false,
                label: Text('临时'),
                icon: Icon(Icons.event_available_outlined),
              ),
            ],
            selected: {_isRoutine},
            onSelectionChanged: (value) => setState(() {
              _isRoutine = value.first;
              if (_isRoutine && _repeat == ReminderRepeat.once) {
                _repeat = ReminderRepeat.daily;
              }
            }),
          ),
          const SizedBox(height: 18),

          // 时间（两种类型都需要）
          Text('时间', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.access_time_rounded),
            label: Text(
              formatHm(_time.hour, _time.minute),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 18),

          if (_isRoutine) ...[
            Text('重复方式', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ReminderRepeat>(
              segments: const [
                ButtonSegment(value: ReminderRepeat.daily, label: Text('每天')),
                ButtonSegment(value: ReminderRepeat.weekly, label: Text('每周固定几天')),
              ],
              selected: {_repeat},
              onSelectionChanged: (value) =>
                  setState(() => _repeat = value.first),
            ),
            if (_repeat == ReminderRepeat.weekly) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: List.generate(7, (index) {
                  final weekday = index + 1;
                  final selected = _weekdays.contains(weekday);
                  return FilterChip(
                    label: Text(weekdayLabel(weekday)),
                    selected: selected,
                    onSelected: (value) => setState(() {
                      if (value) {
                        _weekdays = [..._weekdays, weekday]..sort();
                      } else {
                        _weekdays =
                            _weekdays.where((e) => e != weekday).toList();
                      }
                    }),
                  );
                }),
              ),
            ],
          ] else ...[
            Text('日期', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('今天'),
                  selected: _date == todayKey(),
                  onSelected: (_) => setState(() => _date = todayKey()),
                ),
                ChoiceChip(
                  label: const Text('明天'),
                  selected:
                      _date == dateKeyOf(DateTime.now().add(const Duration(days: 1))),
                  onSelected: (_) => setState(
                    () => _date =
                        dateKeyOf(DateTime.now().add(const Duration(days: 1))),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(relativeDateLabel(_date)),
                  onPressed: _pickDate,
                ),
              ],
            ),
          ],

          const SizedBox(height: 18),
          Text('归属', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ReminderScope>(
            segments: const [
              ButtonSegment(
                value: ReminderScope.life,
                label: Text('生活'),
                icon: Icon(Icons.home_outlined),
              ),
              ButtonSegment(
                value: ReminderScope.work,
                label: Text('工作'),
                icon: Icon(Icons.work_outline),
              ),
            ],
            selected: {_scope},
            onSelectionChanged: (value) => setState(() => _scope = value.first),
          ),

          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('闹钟模式'),
            subtitle: const Text('响铃 + 震动 + 点亮屏幕，适合起床和重要节点'),
            value: _alarmStyle,
            onChanged: (value) => setState(() => _alarmStyle = value),
          ),

        ],
      ),
    );
  }
}
