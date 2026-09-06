import '../models/daily_review.dart';
import '../models/memo_item.dart';
import '../models/reminder_item.dart';
import 'storage_service.dart';

/// 同步数据包：一端的全量数据（含软删除记录）。
///
/// 传输时以 JSON 表示，接收方按 id/dateKey 与本地数据逐条合并。
class SyncPayload {
  SyncPayload({
    required this.memos,
    required this.reminders,
    required this.reviews,
    required this.settings,
    required this.deviceId,
    required this.deviceName,
    DateTime? syncedAt,
  }) : syncedAt = syncedAt ?? DateTime.now();

  final List<MemoItem> memos;
  final List<ReminderItem> reminders;
  final List<DailyReview> reviews;
  final AppSettings settings;
  final String deviceId;
  final String deviceName;
  final DateTime syncedAt;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'syncedAt': syncedAt.toUtc().toIso8601String(),
        'memos': memos.map((e) => e.toJson()).toList(),
        'reminders': reminders.map((e) => e.toJson()).toList(),
        'reviews': reviews.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      };

  factory SyncPayload.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> mapsOf(Object? raw) {
      if (raw is! List) return <Map<String, dynamic>>[];
      return raw.whereType<Map<String, dynamic>>().toList();
    }

    return SyncPayload(
      memos: mapsOf(json['memos']).map(MemoItem.fromJson).toList(),
      reminders: mapsOf(json['reminders']).map(ReminderItem.fromJson).toList(),
      reviews: mapsOf(json['reviews']).map(DailyReview.fromJson).toList(),
      settings: json['settings'] is Map<String, dynamic>
          ? AppSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : AppSettings(),
      deviceId: (json['deviceId'] as String?) ?? '',
      deviceName: (json['deviceName'] as String?) ?? '',
      syncedAt: json['syncedAt'] == null
          ? null
          : DateTime.tryParse(json['syncedAt'] as String),
    );
  }
}

/// 一类数据的合并统计
class MergeStats {
  const MergeStats({this.added = 0, this.updated = 0, this.removed = 0});

  final int added;
  final int updated;
  final int removed;

  MergeStats operator +(MergeStats other) => MergeStats(
        added: added + other.added,
        updated: updated + other.updated,
        removed: removed + other.removed,
      );

  int get total => added + updated + removed;

  bool get isEmpty => total == 0;
}

/// 合并结果：合并后的完整数据包 + 各类数据的变更统计
class MergeResult {
  const MergeResult({
    required this.payload,
    required this.memoStats,
    required this.reminderStats,
    required this.reviewStats,
    required this.settingsChanged,
  });

  final SyncPayload payload;
  final MergeStats memoStats;
  final MergeStats reminderStats;
  final MergeStats reviewStats;
  final bool settingsChanged;

  MergeStats get totalStats => memoStats + reminderStats + reviewStats;
}

class _Merged<T> {
  _Merged(this.items, this.stats);

  final List<T> items;
  final MergeStats stats;
}

/// 按 key 配对合并两组数据：谁的最后修改时间新就听谁的。
/// 只有本地没有的（远端新增）才会计入 added。
_Merged<T> _mergeByKey<T>(
  List<T> local,
  List<T> remote, {
  required String Function(T) keyOf,
  required DateTime Function(T) updatedAtOf,
  required bool Function(T) deletedOf,
}) {
  final localMap = <String, T>{for (final e in local) keyOf(e): e};
  final remoteMap = <String, T>{for (final e in remote) keyOf(e): e};

  final result = <T>[];
  var added = 0;
  var updated = 0;
  var removed = 0;

  for (final key in <String>{...localMap.keys, ...remoteMap.keys}) {
    final l = localMap[key];
    final r = remoteMap[key];

    if (l == null && r != null) {
      result.add(r);
      added++;
      continue;
    }
    if (l != null && r == null) {
      result.add(l);
      continue;
    }
    if (l == null || r == null) continue;

    if (updatedAtOf(r).isAfter(updatedAtOf(l))) {
      result.add(r);
      if (deletedOf(r) && !deletedOf(l)) {
        removed++;
      } else {
        updated++;
      }
    } else {
      result.add(l);
    }
  }

  return _Merged(result, MergeStats(
    added: added,
    updated: updated,
    removed: removed,
  ));
}

/// 合并两端的数据包。
///
/// 这个合并是**对称的**：无论谁当 local 谁当 remote，合并结果都一致。
/// 因此流程是——手机把数据发给 PC，PC 合并后把结果回传，手机再应用，
/// 两端就得到完全相同的数据。
MergeResult mergePayloads({
  required SyncPayload local,
  required SyncPayload remote,
}) {
  final memos = _mergeByKey<MemoItem>(
    local.memos,
    remote.memos,
    keyOf: (e) => e.id,
    updatedAtOf: (e) => e.updatedAt,
    deletedOf: (e) => e.deleted,
  );
  final reminders = _mergeByKey<ReminderItem>(
    local.reminders,
    remote.reminders,
    keyOf: (e) => e.id,
    updatedAtOf: (e) => e.updatedAt,
    deletedOf: (e) => e.deleted,
  );
  final reviews = _mergeByKey<DailyReview>(
    local.reviews,
    remote.reviews,
    keyOf: (e) => e.dateKey,
    updatedAtOf: (e) => e.updatedAt,
    deletedOf: (e) => e.deleted,
  );

  final settingsChanged =
      remote.settings.updatedAt.isAfter(local.settings.updatedAt);

  return MergeResult(
    payload: SyncPayload(
      memos: memos.items,
      reminders: reminders.items,
      reviews: reviews.items,
      settings: settingsChanged ? remote.settings : local.settings,
      deviceId: local.deviceId,
      deviceName: local.deviceName,
    ),
    memoStats: memos.stats,
    reminderStats: reminders.stats,
    reviewStats: reviews.stats,
    settingsChanged: settingsChanged,
  );
}
