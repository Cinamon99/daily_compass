import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/device_identity.dart';
import '../services/sync_client.dart';
import '../services/sync_server.dart';
import '../state/app_state_scope.dart';
import 'common.dart';

const String _kHostKey = 'data.sync_host';
const String _kPortKey = 'data.sync_port';

/// 同步面板：桌面端开启服务等待手机连接，手机端填地址点「更新数据」。
Future<void> showSyncSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _SyncSheet(),
  );
}

class _SyncSheet extends StatefulWidget {
  const _SyncSheet();

  @override
  State<_SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends State<_SyncSheet> {
  final SyncClient _client = SyncClient();
  final TextEditingController _addressController = TextEditingController();

  bool _busy = false;
  String _message = '';
  List<String> _ips = <String>[];
  int _port = 8777;

  bool get _isDesktop => DeviceIdentity.isDesktop;

  @override
  void initState() {
    super.initState();
    SyncServer.instance.onLog = _onServerLog;
    _load();
  }

  @override
  void dispose() {
    SyncServer.instance.onLog = null;
    _addressController.dispose();
    super.dispose();
  }

  void _onServerLog(String message) {
    if (!mounted) return;
    setState(() => _message = message);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_kHostKey) ?? '';
    final port = prefs.getInt(_kPortKey);
    final ips = _isDesktop ? await DeviceIdentity.localIpAddresses() : <String>[];
    if (!mounted) return;
    setState(() {
      _addressController.text = host;
      if (port != null) _port = port;
      _ips = ips;
      if (SyncServer.instance.isRunning) {
        _message = '同步服务运行中，端口 ${SyncServer.instance.port}';
      }
    });
  }

  Future<void> _saveAddress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHostKey, _addressController.text.trim());
    await prefs.setInt(_kPortKey, _port);
  }

  Future<void> _toggleServer(bool value) async {
    final state = AppStateScope.read(context);
    setState(() => _busy = true);
    try {
      if (value) {
        final port = await SyncServer.instance.start(state, port: _port);
        final ips = await DeviceIdentity.localIpAddresses();
        if (!mounted) return;
        setState(() {
          _ips = ips;
          _message = '同步服务已开启（端口 $port）。\n'
              '在手机上打开「同步」，填入下面的地址后点「更新数据」。';
        });
      } else {
        await SyncServer.instance.stop();
        if (!mounted) return;
        setState(() => _message = '同步服务已关闭');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = '启动失败：$e\n若提示端口被占用，换一个端口重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    final input = _addressController.text.trim();
    if (input.isEmpty) {
      setState(() => _message = '请先填写电脑的地址，例如 192.168.1.5:8777');
      return;
    }

    final address = SyncClient.parseAddress(input, defaultPort: _port);
    final state = AppStateScope.read(context);
    setState(() {
      _busy = true;
      _message = '正在连接 ${address.host}:${address.port} …';
    });

    try {
      final deviceId = await DeviceIdentity.id();
      final payload = state.buildPayload(
        deviceId: deviceId,
        deviceName: DeviceIdentity.name(),
      );
      final outcome = await _client.sync(
        host: address.host,
        port: address.port,
        payload: payload,
      );
      await state.applyMerged(outcome.payload);
      await _saveAddress();
      if (!mounted) return;

      final stats = outcome.stats;
      setState(() {
        _message = stats.isEmpty
            ? '同步完成，两端数据已经一致'
            : '同步完成：新增 ${stats.added} 条，更新 ${stats.updated} 条，删除 ${stats.removed} 条';
      });
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() => _message = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = '同步失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SheetContainer(
      title: '同步',
      subtitle: _isDesktop ? '开启服务，让手机连上来更新数据' : '连接电脑，把两端的数据合并',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isDesktop)
            ..._buildServerSection(theme)
          else
            ..._buildClientSection(theme),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_message, style: theme.textTheme.bodyMedium),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '同步是双向合并：每条数据都带最后修改时间，哪一端改得晚就保留哪一端，'
            '删除操作也会同步到另一端。数据只在同一 WiFi 内传输，不会上传到任何服务器。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildServerSection(ThemeData theme) {
    final server = SyncServer.instance;
    return <Widget>[
      Card(
        child: SwitchListTile(
          title: const Text('开启同步服务'),
          subtitle: Text(server.isRunning
              ? '正在监听端口 ${server.port}'
              : '开启后，手机才能连上这台电脑'),
          value: server.isRunning,
          onChanged: _busy ? null : _toggleServer,
        ),
      ),
      if (server.isRunning) ...[
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('在手机上填写这个地址', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                if (_ips.isEmpty)
                  Text(
                    '没有检测到局域网 IP，请确认电脑已连接 WiFi 或有线网络。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  )
                else
                  for (final ip in _ips)
                    _AddressRow(address: '$ip:${server.port}'),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildClientSection(ThemeData theme) {
    return <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '电脑地址',
                  hintText: '192.168.1.5:8777',
                  prefixIcon: Icon(Icons.computer_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sync(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _sync,
                  icon: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(_busy ? '正在同步…' : '更新数据'),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(address, style: theme.textTheme.titleMedium),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: '复制地址',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: address));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('已复制 $address')));
            },
          ),
        ],
      ),
    );
  }
}
