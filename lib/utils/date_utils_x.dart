import 'package:intl/intl.dart';

/// 统一的日期键格式：yyyy-MM-dd
final DateFormat _keyFormat = DateFormat('yyyy-MM-dd');

String dateKeyOf(DateTime d) => _keyFormat.format(d);

DateTime parseDateKey(String key) => _keyFormat.parse(key);

String todayKey() => dateKeyOf(DateTime.now());

/// 星期几的中文简称，DateTime.monday == 1 ... DateTime.sunday == 7
const List<String> weekdayShort = ['', '一', '二', '三', '四', '五', '六', '日'];

String weekdayLabel(int weekday) => '周${weekdayShort[weekday]}';

String formatHm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// 把一组星期序号排好序并转成可读文本，例如 [1,3,5] -> "周一、周三、周五"
String weekdaysText(List<int> weekdays) {
  final sorted = [...weekdays]..sort();
  if (sorted.isEmpty) return '未选择';
  if (sorted.length == 7) return '每天';
  return sorted.map(weekdayLabel).join('、');
}

/// 距离目标时刻还有多久的可读描述，例如 "2小时15分后"
String countdownText(DateTime target) {
  final diff = target.difference(DateTime.now());
  if (diff.isNegative) return '已过期';
  final totalMinutes = diff.inMinutes;
  final days = totalMinutes ~/ (60 * 24);
  final hours = (totalMinutes % (60 * 24)) ~/ 60;
  final minutes = totalMinutes % 60;
  if (days > 0) return '$days天$hours小时后';
  if (hours > 0) return '$hours小时$minutes分后';
  if (minutes > 0) return '$minutes分钟后';
  return '即将';
}

/// 相对日期的可读标签：今天 / 明天 / 昨天 / M月D日
String relativeDateLabel(String key) {
  if (key.isEmpty) return '';
  if (key == todayKey()) return '今天';
  final target = parseDateKey(key);
  final diff = target.difference(parseDateKey(todayKey())).inDays;
  if (diff == 1) return '明天';
  if (diff == -1) return '昨天';
  if (diff > 1 && diff < 7) return '$diff天后';
  if (diff < -1 && diff > -7) return '${-diff}天前';
  if (target.year != DateTime.now().year) {
    return '${target.year}/${target.month}/${target.day}';
  }
  return '${target.month}月${target.day}日';
}
