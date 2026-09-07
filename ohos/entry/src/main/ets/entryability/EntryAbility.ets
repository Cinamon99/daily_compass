// 每日罗盘 · 鸿蒙入口 Ability
// 在 configureFlutterEngine 中注册 MethodChannel('compass/notifications')，
// 把 Flutter 侧的排程/取消请求转给 NotificationBridge（原生 reminderAgent）。
//
// ⚠️ Flutter-OHOS 的 MethodChannel API 与本文件结构请以你本机 SDK 为准。

import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { MethodChannel, StandardMethodCodec } from '@ohos/flutter_ohos';
import { NotificationBridge } from '../bridge/NotificationBridge';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);

    const messenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    const channel = new MethodChannel(
      messenger,
      'compass/notifications',
      StandardMethodCodec.INSTANCE
    );

    channel.setMethodCallHandler((call, result) => {
      switch (call.method) {
        case 'requestPermission':
          NotificationBridge.requestPermission()
            .then((ok: boolean) => result.success(ok));
          break;
        case 'schedule':
          NotificationBridge.schedule(call.arguments as Record<string, Object>)
            .then(() => result.success(null))
            .catch((e: Error) => result.error('SCHEDULE_FAILED', e.message, null));
          break;
        case 'cancel':
          NotificationBridge.cancel((call.argument('id') as number) ?? 0)
            .then(() => result.success(null));
          break;
        case 'cancelAll':
          NotificationBridge.cancelAll()
            .then(() => result.success(null));
          break;
        case 'showTest':
          NotificationBridge.showTest(call.arguments as Record<string, Object>)
            .then(() => result.success(null));
          break;
        default:
          result.notImplemented();
      }
    });
  }
}
