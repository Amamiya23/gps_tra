// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gpx_photo_geotagger/main.dart';

void main() {
  testWidgets('renders app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const GpxPhotoGeotaggerApp());

    expect(find.text('照片轨迹写入'), findsWidgets);
    expect(find.text('选择 GPX 轨迹'), findsOneWidget);
    expect(find.text('开始写入'), findsNothing);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
