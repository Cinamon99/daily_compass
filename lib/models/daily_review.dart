/// 每日总结与反思。以日期键（yyyy-MM-dd）为主键，一天一条。
class DailyReview {
  DailyReview({
    required this.dateKey,
    this.summary = '',
    this.reflection = '',
    this.score = 7,
    this.mood = 3,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// 日期键，格式 yyyy-MM-dd
  final String dateKey;
  /// 今日总结：做了什么、完成了什么
  String summary;
  /// 反思与改进：哪里可以做得更好
  String reflection;
  /// 自我评分 1~10
  int score;
  /// 心情 1~5
  int mood;
  DateTime updatedAt;

  bool get isEmpty => summary.trim().isEmpty && reflection.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'summary': summary,
        'reflection': reflection,
        'score': score,
        'mood': mood,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DailyReview.fromJson(Map<String, dynamic> json) => DailyReview(
        dateKey: (json['dateKey'] as String?) ?? '',
        summary: (json['summary'] as String?) ?? '',
        reflection: (json['reflection'] as String?) ?? '',
        score: (json['score'] as int?) ?? 7,
        mood: (json['mood'] as int?) ?? 3,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}

/// 心情的展示配置
class MoodDef {
  const MoodDef(this.value, this.emoji, this.label);

  final int value;
  final String emoji;
  final String label;
}

const List<MoodDef> moodDefs = [
  MoodDef(1, '😞', '低落'),
  MoodDef(2, '😕', '有点累'),
  MoodDef(3, '😐', '平常'),
  MoodDef(4, '🙂', '不错'),
  MoodDef(5, '😄', '很棒'),
];

MoodDef moodOf(int value) =>
    moodDefs.firstWhere((m) => m.value == value, orElse: () => moodDefs[2]);

/// 评分对应的评语，给主页和总结页用
String scoreComment(int score) {
  if (score >= 9) return '非常充实的一天';
  if (score >= 8) return '状态很好，保持住';
  if (score >= 6) return '稳扎稳打的一天';
  if (score >= 4) return '略有遗憾，明天补上';
  return '今天不太顺，调整一下节奏';
}
