import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../state/app_state.dart';
import 'device_identity.dart';
import 'sync_payload.dart';

/// 桌面端（Windows / Mac）的同步服务。
///
/// 手机连上同一个 WiFi 后主动把数据 POST 过来，本端合并后把结果回传，
/// 两端就得到完全一致的数据。桌面端只做被动响应，不需要知道手机的 IP。
class SyncServer {
  SyncServer._();

  /// 全局单例：设置弹层关掉之后，服务仍然在后台等着手机连上来
  static final SyncServer instance = SyncServer._();

  /// 日志回调，界面可实时显示同步状态
  void Function(String message)? onLog;

  HttpServer? _server;
  AppState? _state;
  String _deviceId = '';
  String _deviceName = '';

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  Future<int> start(AppState state, {int port = 8777}) async {
    _state = state;
    _deviceId = await DeviceIdentity.id();
    _deviceName = DeviceIdentity.name();

    await stop();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    _log('同步服务已启动，端口 ${server.port}');
    server.listen(
      _handle,
      onError: (Object e) => _log('同步服务异常：$e'),
    );
    return server.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
      _log('同步服务已停止');
    }
  }

  void _log(String message) {
    debugPrint('[SyncServer] $message');
    onLog?.call(message);
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;

    if (request.method == 'GET' && (path == '/' || path == '/ping')) {
      return _respond(
        request,
        <String, dynamic>{
          'ok': true,
          'service': 'daily-compass',
          'deviceName': _deviceName,
          'version': 1,
        },
      );
    }

    if (request.method == 'POST' && path == '/sync') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return _respond(
            request,
            <String, dynamic>{'ok': false, 'error': '数据格式不正确'},
            status: HttpStatus.badRequest,
          );
        }

        final appState = _state;
        if (appState == null) {
          return _respond(
            request,
            <String, dynamic>{'ok': false, 'error': '同步服务尚未就绪'},
            status: HttpStatus.internalServerError,
          );
        }

        final remote = SyncPayload.fromJson(decoded);
        final local = appState.buildPayload(
          deviceId: _deviceId,
          deviceName: _deviceName,
        );
        final merged = mergePayloads(local: local, remote: remote);
        await appState.applyMerged(merged.payload);

        final stats = merged.totalStats;
        _log('同步完成：新增 ${stats.added}，更新 ${stats.updated}，删除 ${stats.removed}');

        return _respond(
          request,
          <String, dynamic>{
            'ok': true,
            'payload': merged.payload.toJson(),
            'stats': <String, dynamic>{
              'added': stats.added,
              'updated': stats.updated,
              'removed': stats.removed,
            },
          },
        );
      } catch (e) {
        _log('同步失败：$e');
        return _respond(
          request,
          <String, dynamic>{'ok': false, 'error': '$e'},
          status: HttpStatus.internalServerError,
        );
      }
    }

    return _respond(
      request,
      <String, dynamic>{'ok': false, 'error': '未知请求'},
      status: HttpStatus.notFound,
    );
  }

  Future<void> _respond(
    HttpRequest request,
    Map<String, dynamic> body, {
    int status = HttpStatus.ok,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}
