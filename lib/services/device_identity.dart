import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 本设备的身份标识。
/// 每次同步都会带上，用于区分数据来自哪一端。首次运行时生成并持久化。
class DeviceIdentity {
  DeviceIdentity._();

  static const _kDeviceId = 'data.device_id';

  static String? _cachedId;

  /// 本设备的唯一 ID（首次调用时生成并保存）
  static Future<String> id() async {
    final cached = _cachedId;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      id = _generate();
      await prefs.setString(_kDeviceId, id);
    }
    _cachedId = id;
    return id;
  }

  static String _generate() {
    final random = Random.secure();
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = List<String>.generate(
      3,
      (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
    ).join();
    return 'dc-$stamp-$salt';
  }

  /// 展示用的设备名
  static String name() {
    if (Platform.isAndroid) return '安卓手机';
    if (Platform.isWindows) return 'Windows 电脑';
    if (Platform.isMacOS) return 'Mac 电脑';
    if (Platform.isLinux) return 'Linux 电脑';
    return '设备';
  }

  /// 桌面端（Windows / mac / Linux）才需要开启同步服务
  static bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// 本机在局域网中的 IP 地址（用于给手机端显示连接地址）
  static Future<List<String>> localIpAddresses() async {
    final result = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.address.startsWith('127.')) continue;
          result.add(addr.address);
        }
      }
    } catch (_) {
      // 取不到就返回空列表，由界面提示
    }
    return result;
  }
}
