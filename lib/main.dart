import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'pages/shell_page.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'state/app_state_scope.dart';
import 'theme/app_theme.dart';

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
        home: const ShellPage(),
      ),
    );
  }
}
