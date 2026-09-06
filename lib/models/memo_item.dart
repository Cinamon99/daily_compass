import '../utils/id.dart';

/// 备忘归属：生活 或 工作
enum MemoCategory { life, work }

extension MemoCategoryX on MemoCategory {
  String get label => this == MemoCategory.life ? '生活' : '工作';
  int get code => this == MemoCategory.life ? 0 : 1;

  static MemoCategory fromCode(int code) =>
      code == 1 ? MemoCategory.work : MemoCategory.life;
}

/// 优先级：0 普通 / 1 重要 / 2 紧急
enum MemoPriority { normal, important, urgent }

extension MemoPriorityX on MemoPriority {
  String get label {
    switch (this) {
      case MemoPriority.normal:
        return '普通';
      case MemoPriority.important:
        return '重要';
      case MemoPriority.urgent:
        return '紧急';
    }
  }

  int get code => index;

  static MemoPriority fromCode(int code) =>
      MemoPriority.values[code.clamp(0, MemoPriority.values.length - 1)];
}

/// 一条生活 / 工作备忘。
/// [planDate] 为排期日期键（yyyy-MM-dd），为空表示"仅备忘、不排期"，
/// 不排期的条目不纳入主页的今日完成进度统计。
class MemoItem {
  MemoItem({
    String? id,
    required this.title,
    this.note = '',
    this.category = MemoCategory.life,
    this.priority = MemoPriority.normal,
    this.done = false,
    this.planDate,
    DateTime? createdAt,
    this.completedAt,
    DateTime? updatedAt,
    this.deleted = false,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String note;
  MemoCategory category;
  MemoPriority priority;
  bool done;
  String? planDate;
  final DateTime createdAt;
  DateTime? completedAt;
  /// 最后修改时间。两端同步时用它判断谁的数据更新，每次改动都会刷新。
  DateTime updatedAt;
  /// 软删除标记。删除后不能直接从列表移除，否则同步时会当成"没有这条"而被另一端重新加回来。
  bool deleted;

  /// 标记本条数据刚被修改（刷新 updatedAt）
  void touch() {
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'category': category.code,
        'priority': priority.code,
        'done': done,
        'planDate': planDate,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  factory MemoItem.fromJson(Map<String, dynamic> json) => MemoItem(
        id: json['id'] as String?,
        title: (json['title'] as String?) ?? '',
        note: (json['note'] as String?) ?? '',
        category: MemoCategoryX.fromCode((json['category'] as int?) ?? 0),
        priority: MemoPriorityX.fromCode((json['priority'] as int?) ?? 0),
        done: (json['done'] as bool?) ?? false,
        planDate: json['planDate'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.tryParse(json['completedAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
        deleted: (json['deleted'] as bool?) ?? false,
      );

  MemoItem copyWith({
    String? title,
    String? note,
    MemoCategory? category,
    MemoPriority? priority,
    bool? done,
    Object? planDate = _sentinel,
  }) {
    return MemoItem(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      done: done ?? this.done,
      planDate: identical(planDate, _sentinel)
          ? this.planDate
          : planDate as String?,
      createdAt: createdAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
      deleted: deleted,
    );
  }
}

const Object _sentinel = Object();
