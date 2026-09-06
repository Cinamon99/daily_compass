import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:flutter/material.dart' hide DayPeriod;

import '../models/daily_review.dart';
import '../services/device_identity.dart';
import '../utils/date_utils_x.dart';
import '../utils/schedule_utils.dart';

/// 导出格式
enum ExportFormat {
  excel('Excel', 'xlsx'),
  pdf('PDF', 'pdf'),
  text('文本', 'txt');

  const ExportFormat(this.label, this.extension);

  final String label;
  final String extension;
}

/// 导出结果
class ExportResult {
  ExportResult({
    required this.path,
    required this.format,
    required this.shared,
  });

  /// 文件保存路径
  final String path;
  final ExportFormat format;

  /// 手机端通过系统分享面板发出，桌面端直接存到下载目录
  final bool shared;

  String get fileName => path.split(Platform.pathSeparator).last;
}

/// 把日程表和每日总结导出成 Excel / PDF / 文本文件。
class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  static const String _fontAsset = 'assets/fonts/ChineseSubset.ttf';

  pw.Font? _font;

  // ---------------------------------------------------------------- 日程表

  /// 导出日程表。手机端导出后会弹出系统分享面板，桌面端直接保存到下载目录。
  Future<ExportResult> exportSchedule(
    List<DailySchedule> days,
    ExportFormat format,
  ) async {
    final bytes = switch (format) {
      ExportFormat.excel => _scheduleExcel(days),
      ExportFormat.pdf => await _schedulePdf(days),
      ExportFormat.text => _textBytes(_scheduleText(days)),
    };
    return _save(bytes, '每日罗盘_日程表_${_todayKey()}', format);
  }

  // ---------------------------------------------------------------- 总结

  /// 导出每日总结
  Future<ExportResult> exportReviews(
    List<DailyReview> reviews,
    ExportFormat format,
  ) async {
    final bytes = switch (format) {
      ExportFormat.excel => _reviewsExcel(reviews),
      ExportFormat.pdf => await _reviewsPdf(reviews),
      ExportFormat.text => _textBytes(_reviewsText(reviews)),
    };
    return _save(bytes, '每日罗盘_总结_${_todayKey()}', format);
  }

  // ---------------------------------------------------------------- Excel

  Uint8List _scheduleExcel(List<DailySchedule> days) {
    final excel = Excel.createExcel();
    final first = excel.sheets.keys.first;
    excel.rename(first, '日程表');
    final sheet = excel['日程表'];

    sheet.appendRow([
      TextCellValue('日期'),
      TextCellValue('星期'),
      TextCellValue('上午'),
      TextCellValue('下午'),
      TextCellValue('晚上'),
    ]);

    for (final day in days) {
      sheet.appendRow([
        TextCellValue(day.dateKey),
        TextCellValue(_weekdayLabel(day.date.weekday)),
        TextCellValue(_eventsText(day.morning, multiline: true)),
        TextCellValue(_eventsText(day.afternoon, multiline: true)),
        TextCellValue(_eventsText(day.evening, multiline: true)),
      ]);
    }
    _setColumnWidths(sheet, [12, 8, 30, 30, 30]);

    return Uint8List.fromList(excel.encode() ?? <int>[]);
  }

  Uint8List _reviewsExcel(List<DailyReview> reviews) {
    final excel = Excel.createExcel();
    final first = excel.sheets.keys.first;
    excel.rename(first, '每日总结');
    final sheet = excel['每日总结'];

    sheet.appendRow([
      TextCellValue('日期'),
      TextCellValue('星期'),
      TextCellValue('总结'),
      TextCellValue('反思与改进'),
      TextCellValue('评分'),
      TextCellValue('心情'),
      TextCellValue('更新时间'),
    ]);

    for (final review in reviews) {
      final date = DateTime.tryParse(review.dateKey);
      sheet.appendRow([
        TextCellValue(review.dateKey),
        TextCellValue(date == null ? '' : _weekdayLabel(date.weekday)),
        TextCellValue(review.summary),
        TextCellValue(review.reflection),
        IntCellValue(review.score),
        TextCellValue(moodOf(review.mood).label),
        TextCellValue(_formatDateTime(review.updatedAt)),
      ]);
    }
    _setColumnWidths(sheet, [12, 8, 40, 40, 8, 10, 20]);

    return Uint8List.fromList(excel.encode() ?? <int>[]);
  }

  void _setColumnWidths(Sheet sheet, List<double> widths) {
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }

  // ---------------------------------------------------------------- PDF

  Future<Uint8List> _schedulePdf(List<DailySchedule> days) async {
    final font = await _chineseFont();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _pdfHeader('每日任务安排表', context),
        build: (context) => [
          for (final day in days) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              '${day.dateKey} 星期${_weekdayLabel(day.date.weekday)}',
              style: pw.TextStyle(font: font, fontSize: 13),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FixedColumnWidth(46),
                1: const pw.FlexColumnWidth(),
              },
              children: [
                for (final period in DayPeriod.values)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(period.label,
                            style: pw.TextStyle(font: font, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          _eventsText(day.eventsFor(period), multiline: true),
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _reviewsPdf(List<DailyReview> reviews) async {
    final font = await _chineseFont();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _pdfHeader('每日总结与反思', context),
        build: (context) => [
          for (final review in reviews) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              '${review.dateKey}　评分 ${review.score}/10　${moodOf(review.mood).label}',
              style: pw.TextStyle(font: font, fontSize: 13),
            ),
            pw.SizedBox(height: 4),
            _pdfSection('今日总结', review.summary, font),
            _pdfSection('反思与改进', review.reflection, font),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfHeader(String title, pw.Context context) {
    final font = _font;
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: font,
          fontSize: 16,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  pw.Widget _pdfSection(String label, String content, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11)),
          pw.Text(
            content.isEmpty ? '（未填写）' : content,
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// PDF 内置的字体不含中文，这里加载打包进来的中文字体子集
  Future<pw.Font> _chineseFont() async {
    final cached = _font;
    if (cached != null) return cached;
    final data = await rootBundle.load(_fontAsset);
    final font = pw.Font.ttf(data);
    _font = font;
    return font;
  }

  // ---------------------------------------------------------------- 文本

  String _scheduleText(List<DailySchedule> days) {
    final buffer = StringBuffer();
    buffer.writeln('每日任务安排表');
    buffer.writeln('导出时间：${_formatDateTime(DateTime.now())}');
    buffer.writeln('');

    for (final day in days) {
      buffer.writeln(
          '【${day.dateKey} 星期${_weekdayLabel(day.date.weekday)}】');
      for (final period in DayPeriod.values) {
        final events = day.eventsFor(period);
        buffer.writeln('  ${period.label}：');
        if (events.isEmpty) {
          buffer.writeln('    （无安排）');
          continue;
        }
        for (final event in events) {
          final time = event.timeText == null ? '' : '${event.timeText} ';
          buffer.writeln('    $time${event.title}（${event.sourceLabel}）');
        }
      }
      buffer.writeln('');
    }
    return buffer.toString();
  }

  String _reviewsText(List<DailyReview> reviews) {
    final buffer = StringBuffer();
    buffer.writeln('每日总结与反思');
    buffer.writeln('导出时间：${_formatDateTime(DateTime.now())}');
    buffer.writeln('');

    for (final review in reviews) {
      buffer.writeln('【${review.dateKey}】');
      buffer.writeln('  评分：${review.score}/10');
      buffer.writeln('  心情：${moodOf(review.mood).label}');
      buffer.writeln('  今日总结：');
      buffer.writeln('    ${review.summary.isEmpty ? '（未填写）' : review.summary}');
      buffer.writeln('  反思与改进：');
      buffer.writeln(
          '    ${review.reflection.isEmpty ? '（未填写）' : review.reflection}');
      buffer.writeln('');
    }
    return buffer.toString();
  }

  /// 加 BOM，避免 Windows 记事本打开中文乱码
  Uint8List _textBytes(String content) {
    return Uint8List.fromList(<int>[
      0xEF, 0xBB, 0xBF,
      ...utf8.encode(content),
    ]);
  }

  // ---------------------------------------------------------------- 保存

  Future<ExportResult> _save(
    Uint8List bytes,
    String name,
    ExportFormat format,
  ) async {
    final fileName = '$name.${format.extension}';
    final dir = DeviceIdentity.isDesktop
        ? await getDownloadsDirectory()
        : await getTemporaryDirectory();
    final target = dir ?? Directory.systemTemp;
    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    final file = File('${target.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);

    // 手机端没有直接可见的下载目录，交给系统分享面板
    if (!DeviceIdentity.isDesktop) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: name,
          text: name,
        ),
      );
      return ExportResult(path: file.path, format: format, shared: true);
    }

    return ExportResult(path: file.path, format: format, shared: false);
  }

  // ---------------------------------------------------------------- 工具

  String _eventsText(List<ScheduleEvent> events, {bool multiline = false}) {
    if (events.isEmpty) return '';
    final separator = multiline ? '\n' : '；';
    return events
        .map((e) {
          final time = e.timeText == null ? '' : '${e.timeText} ';
          return '$time${e.title}（${e.sourceLabel}）';
        })
        .join(separator);
  }

  String _weekdayLabel(int weekday) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    if (weekday < 1 || weekday > 7) return '';
    return labels[weekday - 1];
  }

  String _formatDateTime(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  String _todayKey() => dateKeyOf(DateTime.now());

  // ---------------------------------------------------------------- 选择框

  /// 弹出一个统一的格式选择对话框，返回用户选中的格式（取消为 null）
  static Future<ExportFormat?> pickFormat(
    BuildContext context, {
    String? title,
  }) async {
    final icons = {
      ExportFormat.excel: Icons.table_chart_outlined,
      ExportFormat.pdf: Icons.picture_as_pdf_outlined,
      ExportFormat.text: Icons.text_snippet_outlined,
    };
    return showDialog<ExportFormat>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(title ?? '选择导出格式'),
        children: [
          for (final format in ExportFormat.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, format),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(icons[format], size: 22),
                    const SizedBox(width: 14),
                    Text(format.label),
                    const Spacer(),
                    Text(
                      '.${format.extension}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 统一的导出入口：先让用户选格式，再执行导出并给出结果反馈。
  /// [build] 根据选中的格式生成文件。返回一个简短的提示文案（供 SnackBar）。
  static Future<String> runExport(
    BuildContext context, {
    String? title,
    required Future<ExportResult> Function(ExportFormat) build,
  }) async {
    final format = await pickFormat(context, title: title);
    if (format == null) return '已取消';
    final result = await build(format);
    if (DeviceIdentity.isDesktop) {
      return '已导出到：${result.fileName}';
    }
    return '已生成 ${result.fileName}，请选择保存位置';
  }
}
