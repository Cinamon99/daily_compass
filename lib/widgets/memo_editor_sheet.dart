import 'package:flutter/material.dart';

import '../models/memo_item.dart';
import '../state/app_state_scope.dart';
import '../utils/date_utils_x.dart';
import 'common.dart';

/// 打开备忘编辑弹层。
/// [existing] 为空表示新建，返回 true 表示已保存。
Future<bool> showMemoEditor(
  BuildContext context, {
  MemoItem? existing,
  MemoCategory? initialCategory,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MemoEditorSheet(
      existing: existing,
      initialCategory: initialCategory,
    ),
  );
  return result ?? false;
}

class _MemoEditorSheet extends StatefulWidget {
  const _MemoEditorSheet({this.existing, this.initialCategory});

  final MemoItem? existing;
  final MemoCategory? initialCategory;

  @override
  State<_MemoEditorSheet> createState() => _MemoEditorSheetState();
}

class _MemoEditorSheetState extends State<_MemoEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late MemoCategory _category;
  late MemoPriority _priority;
  String? _planDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _category = existing?.category ?? widget.initialCategory ?? MemoCategory.life;
    _priority = existing?.priority ?? MemoPriority.normal;
    _planDate = existing?.planDate ?? (existing == null ? todayKey() : null);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _planDate == null ? now : parseDateKey(_planDate!);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: '选择计划日期',
    );
    if (picked == null || !mounted) return;
    setState(() => _planDate = dateKeyOf(picked));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写备忘内容')));
      return;
    }
    final state = AppStateScope.read(context);
    final existing = widget.existing;

    if (existing == null) {
      await state.addMemo(
        MemoItem(
          title: title,
          note: _note.text.trim(),
          category: _category,
          priority: _priority,
          planDate: _planDate,
        ),
      );
    } else {
      existing.title = title;
      existing.note = _note.text.trim();
      existing.category = _category;
      existing.priority = _priority;
      existing.planDate = _planDate;
      await state.updateMemo(existing);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除备忘'),
        content: const Text('删除后无法恢复，确定要删除吗？'),
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
    await AppStateScope.read(context).removeMemo(existing.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;

    return SheetContainer(
      title: isEditing ? '编辑备忘' : '新建备忘',
      subtitle: _planDate == null ? '不排期，仅作为备忘记录' : '计划日期：${relativeDateLabel(_planDate!)}',
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
              hintText: '要做什么？',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: '补充说明（可选）',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Text('归属', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<MemoCategory>(
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
          ),
          const SizedBox(height: 18),
          Text('优先级', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<MemoPriority>(
            segments: const [
              ButtonSegment(value: MemoPriority.normal, label: Text('普通')),
              ButtonSegment(value: MemoPriority.important, label: Text('重要')),
              ButtonSegment(value: MemoPriority.urgent, label: Text('紧急')),
            ],
            selected: {_priority},
            onSelectionChanged: (value) =>
                setState(() => _priority = value.first),
          ),
          const SizedBox(height: 18),
          Text('计划日期', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('今天'),
                selected: _planDate == todayKey(),
                onSelected: (_) => setState(() => _planDate = todayKey()),
              ),
              ChoiceChip(
                label: const Text('明天'),
                selected: _planDate == dateKeyOf(
                  DateTime.now().add(const Duration(days: 1)),
                ),
                onSelected: (_) => setState(
                  () => _planDate = dateKeyOf(
                    DateTime.now().add(const Duration(days: 1)),
                  ),
                ),
              ),
              ChoiceChip(
                label: const Text('不排期'),
                selected: _planDate == null,
                onSelected: (_) => setState(() => _planDate = null),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(
                  _planDate == null ||
                          _planDate == todayKey() ||
                          _planDate ==
                              dateKeyOf(
                                DateTime.now().add(const Duration(days: 1)),
                              )
                      ? '自选日期'
                      : relativeDateLabel(_planDate!),
                ),
                onPressed: _pickDate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
