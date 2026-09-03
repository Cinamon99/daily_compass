import 'dart:math';

final Random _random = Random();

/// 生成本地唯一 ID（时间戳 + 随机数），不依赖额外第三方包。
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';
