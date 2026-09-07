# 每日罗盘 · 鸿蒙（HarmonyOS NEXT）版移植方案

> 状态：代码地基已写好（见下），**真实出包需要华为开发者账号 + DevEco Studio + 真机签名**，目前用户尚未提供，故仅完成可移植代码与方案。

## 1. 为什么必须做鸿蒙版
- 鸿蒙 NEXT **彻底禁止安卓架构 App 发系统通知**。安卓包经系统自带「卓易通」兼容运行时运行，系统不下发任何通知能力。
- 因此现有 `daily_compass` 安卓 APK 在鸿蒙机上**能用但永远不响提醒**，这是系统限制而非 bug，安卓侧无解。
- 唯一出路：另做一个**鸿蒙原生 / Flutter-OHOS** 版，才能拿到 `reminderAgent` / `notificationManager` 通知能力。

## 2. 技术路线（已选定）：Flutter → OHOS 移植
复用现有 Dart 业务逻辑（数据模型、同步合并、UI、闹钟界面）约 80%，**仅通知层重写**为原生桥接。

### 通知层核心：`reminderAgent`
- 鸿蒙提供系统级提醒代理 `reminderAgent.publishReminder(...)`，**即使 App 已关闭也会准时响**，正是"像真闹钟"要的效果。
- 需要权限 `ohos.permission.PUBLISH_AGENT_REMINDER`（在 `module.json5` 声明，首次调用时系统向用户弹授权）。
- 普通即时通知用 `@ohos/notificationManager`。
- 这和安卓侧 `flutter_local_notifications` 全屏意图 + 最大重要性等价，但更可靠（系统托管）。

## 3. 已完成的代码地基（无需你的资源即可写）
| 文件 | 作用 |
|------|------|
| `lib/services/ohos_notifications.dart` | Dart 侧 `MethodChannel('compass/notifications')` 封装（schedule/cancel/cancelAll/showTest/requestPermission）。用 `Platform.operatingSystem == 'ohos'` 守卫，**普通 Flutter 构建可安全编译、安卓上永不触发**。 |
| `lib/services/notification_service.dart`（已改） | `supported` 增加 ohos；`init/_zonedSchedule/showSnooze/showTestNotification/cancel/cancelAll/ensurePermissions` 均加了 ohos 分支，委托给上面桥接；安卓路径一字未改。 |
| `ohos/entry/src/main/ets/bridge/NotificationBridge.ets` | 原生侧实现：fullScreen=true → `reminderAgent` 系统闹钟；否则 → `notificationManager` 即时通知；含取消/全取消/测试。 |
| `ohos/entry/src/main/ets/entryability/EntryAbility.ets` | 在 `configureFlutterEngine` 注册 MethodChannel，转发到 `NotificationBridge`。 |
| `ohos/entry/src/main/module.permission-snippet.json` | 需合并进 `module.json5` 的 `requestPermissions`（提醒 + 联网权限）。 |

> ⚠️ ArkTS 文件为移植蓝本，具体枚举/方法名需对照你本机 Flutter-OHOS SDK 版本核实（当前无 DevEco 无法编译验证）。

## 4. 出包前你需要准备的（关键资源）
1. **华为开发者账号**（AppGallery Connect，免费）：用于创建应用、调试签名 profile。
2. **DevEco Studio + HarmonyOS SDK**（API 12/NEXT）：开发机安装。
3. **本机 Flutter-OHOS SDK 分支**：即支持 `ohos` 的 Flutter（华为/社区维护的 `flutter_flutter`），以及 `ohpm`、`hvigor` 命令行工具。
4. **真机 UDID + 调试签名**：设备开开发者模式，UDID 注册到账号，拿到 `.p12` + `profile` 才能装到真机验证通知。

## 5. 资源齐备后我的执行步骤
1. 装 Flutter-OHOS SDK，验证 `flutter devices` 能看到 ohos。
2. `flutter create --platforms=ohos .`（生成 `ohos/` 工程骨架，会覆盖/补全我们手写的文件，再把 `NotificationBridge.ets` / `EntryAbility.ets` / 权限片段合并进去）。
3. `flutter pub get`（注意：`flutter_local_notifications` 等插件需有 OHOS 适配，否则要加 `dependency_overrides` 或替换；同步用的 `http` 一般可用）。
4. 编译并安装 `.hap` 到真机：`flutter build hap --debug` + `hdc install`。
5. 真机验证：定时提醒是否关 App 也响、同步能否连 PC、导出是否正常。
6. 通过后配置 Release 签名，发到仓库 Releases 作为鸿蒙版下载。

## 6. 风险与备注
- **插件生态**：`flutter_local_notifications` 在鸿蒙上已被我们绕开（改用桥接），其它插件（如 `wakelock_plus`、`path_provider`、`sqflite`、`pdf`、`excel`）需确认有 OHOS 适配，缺则替换或加平台守卫。
- **导出 PDF 中文字体**：现有子集字体方案应可沿用，但需在 OHOS 资源目录再放一份。
- **全屏闹钟界面**：安卓端的 `AlarmRingPage` 是 Flutter UI，OHOS 上可直接复用；`reminderAgent` 负责"响"，点开后的全屏界面由 Flutter 渲染，无需原生重写。
- **闹钟持续响铃**：`reminderAgent` 的 `ringDuration` 可设较长时长模拟持续响铃，比安卓侧更稳。

## 7. 下一步
等你装好 DevEco/SDK 或提供账号与设备 UDID，我就按第 5 步把 `.hap` 跑通并在真机验收通知。
