import 'package:flutter/material.dart';

import '../models/memo_item.dart';
import '../theme/app_theme.dart';

/// 带标题、图标和可选操作的分区卡片
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    super.key,
    this.icon,
    this.accentColor,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Color? accentColor;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: accentColor ?? theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 空状态提示
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    required this.text,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String text;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 24),
      child: Column(
        children: [
          Icon(
            icon,
            size: compact ? 26 : 40,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// 生活 / 工作 标签
class CategoryChip extends StatelessWidget {
  const CategoryChip({required this.category, super.key, this.compact = false});

  final MemoCategory category;
  final bool compact;

  Color get _color =>
      category == MemoCategory.work ? AppTheme.workColor : AppTheme.lifeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

/// 优先级标签，仅"重要 / 紧急"才显示
class PriorityChip extends StatelessWidget {
  const PriorityChip({required this.priority, super.key});

  final MemoPriority priority;

  @override
  Widget build(BuildContext context) {
    if (priority == MemoPriority.normal) return const SizedBox.shrink();
    final color = priority == MemoPriority.urgent
        ? Colors.redAccent
        : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// 通用底部弹层容器，统一圆角与内边距，自动避让键盘
class SheetContainer extends StatelessWidget {
  const SheetContainer({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.actions,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;

  /// 固定在弹层底部、不随内容滚动的操作栏（如保存 / 删除按钮）。
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 注意：调用方在 showModalBottomSheet 里已开启 useSafeArea，
    // 这里不再重复包 SafeArea，否则底部会多出一段空白。
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ...?actions,
            ],
          ),
          const SizedBox(height: 16),
          // 内容少时贴合内容高度，内容超出可用高度时可滚动
          Flexible(child: SingleChildScrollView(child: child)),
          if (footer != null) ...[
            const SizedBox(height: 16),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// 供弹层使用的主按钮行
class SheetActions extends StatelessWidget {
  const SheetActions({
    required this.onSave,
    super.key,
    this.onDelete,
    this.saveLabel = '保存',
  });

  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onDelete != null)
          IconButton.filledTonal(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: '删除',
          ),
        if (onDelete != null) const SizedBox(width: 12),
        Expanded(
          child: FilledButton(onPressed: onSave, child: Text(saveLabel)),
        ),
      ],
    );
  }
}
