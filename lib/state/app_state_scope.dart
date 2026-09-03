import 'package:flutter/material.dart';

import 'app_state.dart';

/// 把 [AppState] 沿 widget 树向下传递。
/// 页面里用 AppStateScope.of(context) 取用并建立依赖，
/// 状态变化时会自动重建；回调中用 AppStateScope.read(context) 只取不订阅。
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required AppState state,
    required super.child,
    super.key,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope 未在 widget 树中提供');
    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<AppStateScope>();
    final scope = element?.widget as AppStateScope?;
    assert(scope != null, 'AppStateScope 未在 widget 树中提供');
    return scope!.notifier!;
  }
}
