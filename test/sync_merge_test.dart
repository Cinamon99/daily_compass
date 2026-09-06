import 'package:flutter_test/flutter_test.dart';
import 'package:daily_compass/models/daily_review.dart';
import 'package:daily_compass/models/memo_item.dart';
import 'package:daily_compass/services/storage_service.dart';
import 'package:daily_compass/services/sync_payload.dart';

SyncPayload _payload({
  List<MemoItem> memos = const <MemoItem>[],
  List<DailyReview> reviews = const <DailyReview>[],
  AppSettings? settings,
}) {
  return SyncPayload(
    memos: memos,
    reminders: const [],
    reviews: reviews,
    settings: settings ?? AppSettings(),
    deviceId: 'test-device',
    deviceName: '测试设备',
  );
}

void main() {
  test('远端新增的备忘会被合并进来', () {
    final result = mergePayloads(
      local: _payload(),
      remote: _payload(memos: [MemoItem(title: '新任务')]),
    );

    expect(result.payload.memos.length, 1);
    expect(result.payload.memos.first.title, '新任务');
    expect(result.memoStats.added, 1);
  });

  test('修改冲突时保留更新时间更新的一方', () {
    const id = 'memo-1';
    final older = MemoItem(id: id, title: '更旧', updatedAt: DateTime(2026, 1, 1));
    final newer = MemoItem(id: id, title: '新标题', updatedAt: DateTime(2026, 2, 1));

    final fromRemote =
        mergePayloads(local: _payload(memos: [older]), remote: _payload(memos: [newer]));
    expect(fromRemote.payload.memos.single.title, '新标题');
    expect(fromRemote.memoStats.updated, 1);

    final localWins =
        mergePayloads(local: _payload(memos: [newer]), remote: _payload(memos: [older]));
    expect(localWins.payload.memos.single.title, '新标题');
    expect(localWins.memoStats.updated, 0);
  });

  test('一端的删除会同步到另一端', () {
    const id = 'memo-2';
    final existing = MemoItem(id: id, title: '待删除', updatedAt: DateTime(2026, 1, 1));
    final deleted = MemoItem(
      id: id,
      title: '待删除',
      updatedAt: DateTime(2026, 3, 1),
      deleted: true,
    );

    final result =
        mergePayloads(local: _payload(memos: [existing]), remote: _payload(memos: [deleted]));

    expect(result.payload.memos.single.deleted, isTrue);
    expect(result.memoStats.removed, 1);
  });

  test('旧的删除不会覆盖之后的新修改', () {
    const id = 'memo-3';
    final deleted = MemoItem(
      id: id,
      title: 't',
      updatedAt: DateTime(2026, 1, 1),
      deleted: true,
    );
    final revived = MemoItem(id: id, title: '改回来了', updatedAt: DateTime(2026, 5, 1));

    final result =
        mergePayloads(local: _payload(memos: [deleted]), remote: _payload(memos: [revived]));

    expect(result.payload.memos.single.deleted, isFalse);
    expect(result.payload.memos.single.title, '改回来了');
  });

  test('合并是对称的：交换两端结果一致', () {
    const id = 'memo-4';
    final a = MemoItem(id: id, title: 'A', updatedAt: DateTime(2026, 1, 1));
    final b = MemoItem(id: id, title: 'B', updatedAt: DateTime(2026, 2, 1));

    final r1 = mergePayloads(local: _payload(memos: [a]), remote: _payload(memos: [b]));
    final r2 = mergePayloads(local: _payload(memos: [b]), remote: _payload(memos: [a]));

    expect(r1.payload.memos.single.title, r2.payload.memos.single.title);
    expect(r1.payload.memos.single.title, 'B');
  });

  test('设置按更新时间取新', () {
    final local = AppSettings(morningHour: 7, updatedAt: DateTime(2026, 1, 1));
    final remote = AppSettings(morningHour: 9, updatedAt: DateTime(2026, 4, 1));

    final result =
        mergePayloads(local: _payload(settings: local), remote: _payload(settings: remote));

    expect(result.payload.settings.morningHour, 9);
    expect(result.settingsChanged, isTrue);
  });

  test('payload 序列化往返不丢字段', () {
    final payload = _payload(
      memos: [MemoItem(title: '任务A')],
      reviews: [DailyReview(dateKey: '2026-09-06', summary: '还不错', score: 8)],
    );

    final restored = SyncPayload.fromJson(payload.toJson());

    expect(restored.memos.single.title, '任务A');
    expect(restored.reviews.single.summary, '还不错');
    expect(restored.reviews.single.score, 8);
    expect(restored.deviceName, '测试设备');
  });

  test('旧版本数据（无 updatedAt/deleted）能安全读入', () {
    final legacy = <String, dynamic>{
      'memos': [
        {'id': 'legacy-1', 'title': '老数据'}
      ],
      'reminders': [],
      'reviews': [],
    };

    final payload = SyncPayload.fromJson(legacy);

    expect(payload.memos.single.title, '老数据');
    expect(payload.memos.single.deleted, isFalse);
    expect(payload.memos.single.updatedAt.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
  });
}
