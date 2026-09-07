import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'pages/alarm_ring_page.dart';
import 'pages/shell_page.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'state/app_state_scope.dart';
import 'theme/app_theme.dart';

/// 全局导航键：通知点击回调（在非 UI 上下文里）需要它来 push 闹钟界面。
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 时区数据与通知插件要在 runApp 之前就绪。
  // flutter test 下没有原生通知平台，跳过初始化。
  final isTest = Platform.environment.containsKey('FLUTTER_TEST');
  if (!isTest) {
    await NotificationService.instance.init();
  }
  runApp(const DailyCompassApp());
}

class DailyCompassApp extends StatefulWidget {
  const DailyCompassApp({super.key});

  @override
  State<DailyCompassApp> createState() => _DailyCompassAppState();
}

class _DailyCompassAppState extends State<DailyCompassApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState();
    _state.load();
    // 通知被点击（含全屏闹钟意图）时，跳到全屏闹钟界面。
    NotificationService.instance.onTap = _routeToAlarm;
  }

  /// 把通知 payload 路由到全屏闹钟界面；导航器未就绪时稍后重试。
  void _routeToAlarm(String? payload) {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => AlarmRingPage(payload: payload),
          fullscreenDialog: true,
        ),
      );
    } else {
      Future.delayed(
        const Duration(milliseconds: 100),
        () => _routeToAlarm(payload),
      );
    }
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: _state,
      child: MaterialApp(
        title: '每日罗盘',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        navigatorKey: navigatorKey,
        home: const ShellPage(),
      ),
    );
  }
}
