import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../state/app_state_scope.dart';
import '../utils/date_utils_x.dart';
import 'common.dart';
import 'sync_sheet.dart';

/// 内置引导提醒的设置弹层
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = AppStateScope.of(context).settings;
  }

  Future<void> _pickTime({
    required bool isMorning,
    required TimeOfDay initial,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isMorning ? '晨间提醒时间' : '总结提醒时间',
    );
    if (picked == null) return;
    setState(() {
      if (isMorning) {
        _settings.morningHour = picked.hour;
        _settings.morningMinute = picked.minute;
      } else {
        _settings.summaryHour = picked.hour;
        _settings.summaryMinute = picked.minute;
      }
    });
    await _commit();
  }

  Future<void> _commit() async {
    await AppStateScope.read(context).updateSettings(_settings);
    if (mounted) setState(() {});
  }

  Future<void> _test() async {
    final ctx = context;
    await NotificationService.instance.showTestNotification();
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('已发送测试通知，若没看到请检查系统通知权限')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SheetContainer(
      title: '设置',
      subtitle: '内置引导提醒与通知调试',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('晨间提醒'),
                  subtitle: Text(
                    '每天 ${formatHm(_settings.morningHour, _settings.morningMinute)} 提示今天的任务与安排',
                  ),
                  value: _settings.morningEnabled,
                  onChanged: (value) {
                    setState(() => _settings.morningEnabled = value);
                    _commit();
                  },
                ),
                if (_settings.morningEnabled)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.wb_sunny_outlined),
                    title: const Text('提醒时间'),
                    trailing: Text(
                      formatHm(_settings.morningHour, _settings.morningMinute),
                      style: theme.textTheme.titleMedium,
                    ),
                    onTap: () => _pickTime(
                      isMorning: true,
                      initial: TimeOfDay(
                        hour: _settings.morningHour,
                        minute: _settings.morningMinute,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('总结提醒'),
                  subtitle: Text(
                    '每天 ${formatHm(_settings.summaryHour, _settings.summaryMinute)} 提醒写当日总结与评分',
                  ),
                  value: _settings.summaryEnabled,
                  onChanged: (value) {
                    setState(() => _settings.summaryEnabled = value);
                    _commit();
                  },
                ),
                if (_settings.summaryEnabled)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.nightlight_outlined),
                    title: const Text('提醒时间'),
                    trailing: Text(
                      formatHm(_settings.summaryHour, _settings.summaryMinute),
                      style: theme.textTheme.titleMedium,
                    ),
                    onTap: () => _pickTime(
                      isMorning: false,
                      initial: TimeOfDay(
                        hour: _settings.summaryHour,
                        minute: _settings.summaryMinute,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('发送测试通知'),
                  subtitle: const Text('验证闹钟能否正常弹出与响铃'),
                  onTap: _test,
                ),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('重新同步所有闹钟'),
                  subtitle: const Text('手动触发一次排程刷新'),
                  onTap: () async {
                    final ctx = context;
                    await AppStateScope.read(ctx).reschedule();
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(const SnackBar(content: Text('已重新同步')));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync_rounded),
                  title: const Text('同步到电脑 / 手机'),
                  subtitle: const Text('同一 WiFi 下手动合并两端数据'),
                  onTap: () => showSyncSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '提示：部分国产 ROM 会限制后台闹钟。若通知不准时，'
              '请在系统设置里把「每日罗盘」加入后台运行白名单，并允许自启动与精确闹钟。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
