import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import 'home_page.dart';
import 'memo_page.dart';
import 'reminder_page.dart';
import 'review_page.dart';

/// 底部导航栏容器，承载主页 / 备忘 / 提醒 / 总结四个页面。
/// 用 IndexedStack 保持各页状态，切换时不重建。
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> with WidgetsBindingObserver {
  int _index = 0;
  late final AppState _state;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: '主页',
    ),
    NavigationDestination(
      icon: Icon(Icons.checklist_outlined),
      selectedIcon: Icon(Icons.checklist_rounded),
      label: '备忘',
    ),
    NavigationDestination(
      icon: Icon(Icons.alarm_outlined),
      selectedIcon: Icon(Icons.alarm_rounded),
      label: '提醒',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_stories_outlined),
      selectedIcon: Icon(Icons.auto_stories_rounded),
      label: '总结',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // initState 中只能读取，不能建立依赖；依赖放在 build 里。
    _state = AppStateScope.read(context);
    NotificationService.instance.onTap = _handleNotificationTap;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePermissions();
    });
  }

  @override
  void dispose() {
    NotificationService.instance.onTap = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台时重新对齐排程，防止系统清理后闹钟丢失
      _state.reschedule();
    }
  }

  Future<void> _ensurePermissions() async {
    try {
      await NotificationService.instance.ensurePermissions();
    } catch (_) {
      // 测试环境或非 Android 平台会失败，忽略即可
    }
  }

  /// 通知点击后的落地页：内置提醒去对应页面，用户提醒去提醒页
  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    if (payload.startsWith('builtin:')) {
      final target = payload.substring('builtin:'.length);
      setState(() => _index = target == 'summary' ? 3 : 0);
      return;
    }
    setState(() => _index = 2);
  }

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(onNavigate: _goTo),
          MemoPage(onNavigate: _goTo),
          ReminderPage(onNavigate: _goTo),
          ReviewPage(onNavigate: _goTo),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        height: 68,
        destinations: _destinations,
      ),
    );
  }
}
