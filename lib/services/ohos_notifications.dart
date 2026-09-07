import 'dart:io';

import 'package:flutter/services.dart';

/// 鸿蒙（HarmonyOS NEXT）通知桥接。
///
/// 为什么需要它：安卓的 `flutter_local_notifications` 在鸿蒙上既编不过、
/// 也拿不到任何通知权限（安卓 App 经「卓易通」兼容运行时，系统不下发通知能力）。
/// 因此鸿蒙端必须改用平台通道（MethodChannel）调用鸿蒙原生的
/// `reminderAgent`（系统级提醒，关 App 也能响，像真闹钟）与
/// `notificationManager`（即时通知）。
///
/// 安全性：所有方法都先用 [isOhos] 守卫，[isOhos] 用
/// `Platform.operatingSystem == 'ohos'` 判断——普通 Flutter（Android/iOS/
/// Windows）构建里这个字符串永远不等于 'ohos'，所以这段代码在其它平台
/// 上**完全不触发、可安全编译**，不会破坏现有安卓 APK。
class OhosNotifications {
  static const MethodChannel _channel =
      MethodChannel('compass/notifications');

  /// 仅在 HarmonyOS NEXT 上为 true。普通 Flutter 构建恒为 false。
  static bool get isOhos => Platform.operatingSystem == 'ohos';

  /// 申请通知/提醒权限。鸿蒙侧在原生层向用户弹授权。
  Future<bool> requestPermission() async {
    if (!isOhos) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  /// 排程一条提醒。
  ///
  /// [triggerMs] 为触发时刻的 UTC 毫秒（由 Dart 端算好下一触发点）。
  /// [fullScreen] 为 true 时用 `reminderAgent` 系统级闹钟（关 App 也能响）；
  /// 为 false 时用普通 `notificationManager` 即时通知风格。
  Future<void> schedule({
    required int id,
    required DateTime scheduled,
    required String title,
    required String body,
    String? payload,
    bool fullScreen = true,
  }) async {
    if (!isOhos) return;
    await _channel.invokeMethod<void>('schedule', <String, Object?>{
      'id': id,
      'triggerMs': scheduled.millisecondsSinceEpoch,
      'title': title,
      'body': body,
      'payload': payload ?? '',
      'fullScreen': fullScreen,
    });
  }

  /// 取消单条提醒。
  Future<void> cancel(int id) async {
    if (!isOhos) return;
    await _channel.invokeMethod<void>('cancel', <String, Object?>{'id': id});
  }

  /// 取消全部提醒。
  Future<void> cancelAll() async {
    if (!isOhos) return;
    await _channel.invokeMethod<void>('cancelAll');
  }

  /// 立即发一条测试通知，用于验证鸿蒙通知是否可用。
  Future<void> showTest() async {
    if (!isOhos) return;
    await _channel.invokeMethod<void>('showTest', <String, Object?>{
      'title': '每日罗盘提醒测试',
      'body': '如果你看到这条，说明鸿蒙通知已经通了',
    });
  }
}
