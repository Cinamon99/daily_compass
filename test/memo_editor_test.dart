import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_compass/main.dart';

void main() {
  testWidgets('添加备忘后列表显示', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DailyCompassApp());
    // 等 AppState.load() 与首帧完成
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 主页"加备忘"快捷入口
    await tester.tap(find.text('加备忘'));
    await tester.pumpAndSettle();

    // 输入标题
    await tester.enterText(find.byType(TextField).first, '去超市买牛奶');
    await tester.pumpAndSettle();

    // 点击保存
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    // 主页应该出现这条备忘
    expect(find.text('去超市买牛奶'), findsOneWidget);

    // 切换到备忘页确认也显示
    await tester.tap(find.text('备忘'));
    await tester.pumpAndSettle();
    expect(find.text('去超市买牛奶'), findsOneWidget);
  });
}
