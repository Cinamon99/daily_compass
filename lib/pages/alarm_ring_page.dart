import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/notification_service.dart';
import '../state/app_state_scope.dart';
import '../utils/date_utils_x.dart';

/// 闹钟响铃时的全屏界面：大字号时间 + 提醒内容 + 关闭 / 稍后提醒。
///
/// 由通知点击（fullScreenIntent 或普通点击）路由进来。进入时点亮屏幕，
/// 退出时恢复。仅安卓端会被触发（通知只在安卓存在）。
class AlarmRingPage extends StatefulWidget {
  const AlarmRingPage({super.key, this.payload});

  /// 通知携带的 payload：提醒 id / builtin:morning / builtin:summary / snooze
  final String? payload;

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
    // 点亮屏幕，避免息屏后看不到闹钟
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    _timer.cancel();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  String get _title {
    final p = widget.payload ?? '';
    if (p.startsWith('builtin:morning')) return '早上好，新的一天开始了';
    if (p.startsWith('builtin:summary')) return '该做今天的总结了';
    if (p.isNotEmpty && !p.startsWith('snooze')) {
      final reminder = AppStateScope.read(context)
          .reminders
          .where((e) => e.id == p)
          .firstOrNull;
      if (reminder != null) return reminder.title;
    }
    return '每日罗盘提醒';
  }

  String get _note {
    final p = widget.payload ?? '';
    if (p.isNotEmpty && !p.startsWith('builtin:') && !p.startsWith('snooze')) {
      final reminder = AppStateScope.read(context)
          .reminders
          .where((e) => e.id == p)
          .firstOrNull;
      if (reminder != null && reminder.note.trim().isNotEmpty) {
        return reminder.note.trim();
      }
    }
    return '';
  }

  void _dismiss() => Navigator.of(context).pop();

  Future<void> _snooze() async {
    await NotificationService.instance.showSnooze(
      _title,
      minutes: 5,
      payload: widget.payload,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已稍后提醒：5 分钟后再响')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _title;
    final note = _note;

    return Scaffold(
      backgroundColor: theme.colorScheme.errorContainer,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                formatHm(_now.hour, _now.minute),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 92,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onErrorContainer,
                  height: 1,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        note,
                        textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onErrorContainer
                            .withValues(alpha: 0.85),
                      ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton.tonal(
                  onPressed: _snooze,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        theme.colorScheme.onErrorContainer.withValues(alpha: 0.16),
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                  child: const Text('稍后提醒（5 分钟）', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton(
                  onPressed: _dismiss,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.onErrorContainer,
                    foregroundColor: theme.colorScheme.errorContainer,
                  ),
                  child: const Text('关闭闹钟', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
