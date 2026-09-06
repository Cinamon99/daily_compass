import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sync_payload.dart';

/// 同步过程中的可预期错误，message 直接展示给用户
class SyncException implements Exception {
  SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 一次同步的结果：合并后的数据 + 变更统计
class SyncOutcome {
  SyncOutcome({required this.payload, required this.stats, this.peerName});

  final SyncPayload payload;
  final MergeStats stats;
  final String? peerName;
}

/// 手机端的同步客户端。主动连到电脑的 IP 和端口，
/// 把本端数据传过去，拿回合并结果。
class SyncClient {
  SyncClient({this.timeout = const Duration(seconds: 10)});

  final Duration timeout;

  /// 解析用户输入的地址，支持 "192.168.1.5:8777" 或 "192.168.1.5"
  static ({String host, int port}) parseAddress(
    String input, {
    int defaultPort = 8777,
  }) {
    var text = input.trim();
    for (final prefix in ['http://', 'https://']) {
      if (text.toLowerCase().startsWith(prefix)) {
        text = text.substring(prefix.length);
      }
    }
    text = text.replaceAll(RegExp(r'/.*$'), '');

    final parts = text.split(':');
    if (parts.length == 2 && parts[1].isNotEmpty) {
      return (
        host: parts[0],
        port: int.tryParse(parts[1]) ?? defaultPort,
      );
    }
    return (host: text, port: defaultPort);
  }

  /// 测试能否连上电脑端的同步服务，返回对方设备名
  Future<String> ping(String host, int port) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.get(host, port, '/ping').timeout(timeout);
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != HttpStatus.ok) {
        throw SyncException('电脑端没有正确响应（${response.statusCode}）');
      }
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['ok'] == true) {
        return (decoded['deviceName'] as String?) ?? '电脑';
      }
      throw SyncException('对方不是每日罗盘的同步服务');
    } on SocketException {
      throw SyncException('连不上电脑。请确认手机和电脑在同一个 WiFi，且电脑端已点开「开启同步」');
    } on TimeoutException {
      throw SyncException('连接超时，请检查 IP 地址和端口是否正确');
    } on SyncException {
      rethrow;
    } catch (_) {
      throw SyncException('连接失败，请检查地址是否正确');
    } finally {
      client.close();
    }
  }

  /// 与电脑端交换并合并数据
  Future<SyncOutcome> sync({
    required String host,
    required int port,
    required SyncPayload payload,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.post(host, port, '/sync').timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload.toJson()));

      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != HttpStatus.ok) {
        throw SyncException('电脑端返回了错误（${response.statusCode}）');
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw SyncException('返回的数据无法解析');
      }
      if (decoded['ok'] != true) {
        throw SyncException((decoded['error'] as String?) ?? '同步失败');
      }

      final rawPayload = decoded['payload'];
      final merged = SyncPayload.fromJson(
        rawPayload is Map<String, dynamic> ? rawPayload : <String, dynamic>{},
      );

      final rawStats = decoded['stats'];
      final stats = rawStats is Map<String, dynamic>
          ? MergeStats(
              added: (rawStats['added'] as int?) ?? 0,
              updated: (rawStats['updated'] as int?) ?? 0,
              removed: (rawStats['removed'] as int?) ?? 0,
            )
          : const MergeStats();

      return SyncOutcome(payload: merged, stats: stats);
    } on SocketException {
      throw SyncException('连不上电脑。请确认手机和电脑在同一个 WiFi，且电脑端已点开「开启同步」');
    } on TimeoutException {
      throw SyncException('连接超时，请检查 IP 地址和端口是否正确');
    } on SyncException {
      rethrow;
    } catch (_) {
      throw SyncException('同步失败，请稍后重试');
    } finally {
      client.close();
    }
  }
}
