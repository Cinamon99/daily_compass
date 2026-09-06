import 'package:flutter/material.dart';

import '../models/daily_review.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../services/export_service.dart';
import '../utils/date_utils_x.dart';
import '../widgets/common.dart';

/// 总结页：写今日总结与反思、自我评分，并查看历史记录
class ReviewPage extends StatelessWidget {
  const ReviewPage({required this.onNavigate, super.key});

  final void Function(int index) onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final theme = Theme.of(context);
    final history = state.sortedReviews;

    return Scaffold(
      appBar: AppBar(
        title: const Text('总结'),
        actions: [
          IconButton(
            onPressed: () async {
              final message = await ExportService.runExport(
                context,
                title: '导出每日总结',
                build: (format) => ExportService.instance.exportReviews(
                  state.sortedReviews,
                  format,
                ),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(message)));
            },
            icon: const Icon(Icons.download_outlined),
            tooltip: '导出总结',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _ReviewForm(dateKey: todayKey(), isToday: true),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                Icons.history_edu_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '历史记录',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatsRow(state: state),
          const SizedBox(height: 16),
          _ScoreTrend(state: state),
          const SizedBox(height: 16),
          if (history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: EmptyHint(
                  text: '还没有历史记录\n写下第一篇总结后就会出现在这里',
                  icon: Icons.auto_stories_outlined,
                  compact: true,
                ),
              ),
            )
          else
            ...history.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryTile(review: review),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 统计概览

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final reviews = state.reviews;
    final avg = state.averageScore;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            value: '${state.reviewStreak}',
            unit: '天',
            label: '连续记录',
            color: AppTheme.accentColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            value: avg == 0 ? '—' : avg.toStringAsFixed(1),
            unit: '',
            label: '平均评分',
            color: AppTheme.lifeColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.auto_stories_rounded,
            value: '${reviews.length}',
            unit: '篇',
            label: '累计总结',
            color: AppTheme.workColor,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (unit.isNotEmpty)
                  Text(unit, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
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

// ------------------------------------------------------------------ 评分趋势

class _ScoreTrend extends StatelessWidget {
  const _ScoreTrend({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = state.recentScores(7);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近 7 天评分',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((entry) {
                  final isToday = entry.dateKey == todayKey();
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _TrendBar(
                        score: entry.score,
                        label: weekdayShort[parseDateKey(entry.dateKey).weekday],
                        isToday: isToday,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.score,
    required this.label,
    required this.isToday,
  });

  final int? score;
  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasScore = score != null;
    final ratio = hasScore ? score! / 10 : 0.0;
    final color = !hasScore
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25)
        : score! >= 8
            ? AppTheme.lifeColor
            : score! >= 6
                ? AppTheme.workColor
                : AppTheme.accentColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasScore)
          Text(
            '$score',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: hasScore ? (ratio * 0.9 + 0.06) : 0.06,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isToday ? '今天' : label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: isToday
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 历史条目

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.review});

  final DailyReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mood = moodOf(review.mood);
    final parsed = parseDateKey(review.dateKey);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => SheetContainer(
            title: '${parsed.month}月${parsed.day}日 的总结',
            subtitle: relativeDateLabel(review.dateKey),
            child: _ReviewForm(dateKey: review.dateKey, isToday: false),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${parsed.day}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      '${parsed.month}月',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(mood.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _scoreColor(review.score).withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${review.score} 分',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _scoreColor(review.score),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            mood.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (review.summary.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        review.summary.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (review.reflection.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '反思：${review.reflection.trim()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 8) return AppTheme.lifeColor;
  if (score >= 6) return AppTheme.workColor;
  return AppTheme.accentColor;
}

// ------------------------------------------------------------------ 编辑表单

/// 某一天的总结编辑表单。今日用它直接内联在页面上，
/// 历史记录里通过弹层复用同一个组件。
class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.dateKey, required this.isToday});

  final String dateKey;
  final bool isToday;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> with WidgetsBindingObserver {
  late final TextEditingController _summary;
  late final TextEditingController _reflection;
  late int _score;
  late int _mood;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final existing = AppStateScope.read(context).reviewOf(widget.dateKey);
    _summary = TextEditingController(text: existing?.summary ?? '');
    _reflection = TextEditingController(text: existing?.reflection ?? '');
    _score = existing?.score ?? 7;
    _mood = existing?.mood ?? 3;
    _summary.addListener(_markDirty);
    _reflection.addListener(_markDirty);
    if (widget.isToday) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从后台回来可能已经跨天，重新绑定今天的数据
    if (state == AppLifecycleState.resumed && _isToday) {
      _rebind();
    }
  }

  bool get _isToday => widget.dateKey == todayKey();

  void _rebind() {
    final existing = AppStateScope.read(context).reviewOf(widget.dateKey);
    if (!_dirty) {
      _summary.text = existing?.summary ?? '';
      _reflection.text = existing?.reflection ?? '';
    }
    if (mounted) setState(() {});
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    if (widget.isToday) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _summary.removeListener(_markDirty);
    _reflection.removeListener(_markDirty);
    _summary.dispose();
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = AppStateScope.read(context);
    final existing = state.reviewOf(widget.dateKey);
    final review = DailyReview(
      dateKey: widget.dateKey,
      summary: _summary.text.trim(),
      reflection: _reflection.text.trim(),
      score: _score,
      mood: _mood,
    );
    await state.saveReview(review);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existing == null ? '已保存今天的总结' : '已更新')),
    );
    if (!widget.isToday) Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这篇总结'),
        content: const Text('删除后无法恢复，确定吗？'),
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
    await AppStateScope.read(context).removeReview(widget.dateKey);
    if (!mounted) return;
    if (!widget.isToday) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final parsed = parseDateKey(widget.dateKey);
    final hasRecord =
        AppStateScope.of(context).reviewOf(widget.dateKey) != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isToday ? '今日总结' : '编辑总结',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${parsed.month}月${parsed.day}日 ${weekdayLabel(parsed.weekday)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _summary,
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: '今天完成了什么？有哪些进展？',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reflection,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: '哪里可以做得更好？明天打算怎么调整？',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // 自我评分
            Row(
              children: [
                Text('自我评分', style: theme.textTheme.labelLarge),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _scoreColor(_score).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_score 分',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _scoreColor(_score),
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _score.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: _scoreColor(_score),
              onChanged: (value) => setState(() {
                _score = value.round();
                _dirty = true;
              }),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1 分',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    scoreComment(_score),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '10 分',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Text('今天的心情', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Row(
              children: moodDefs.map((def) {
                final selected = def.value == _mood;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: def.value == 5 ? 0 : 6,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() {
                        _mood = def.value;
                        _dirty = true;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primary.withValues(alpha: 0.14)
                              : scheme.onSurfaceVariant.withValues(
                                  alpha: 0.06,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : Colors.transparent,
                            width: 1.4,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              def.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              def.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            Row(
              children: [
                if (hasRecord)
                  IconButton.filledTonal(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: '删除',
                  ),
                if (hasRecord) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(_dirty ? '保存修改' : '已保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
