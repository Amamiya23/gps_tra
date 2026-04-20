// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gpx_photo_geotagger/app_theme.dart';
import 'package:gpx_photo_geotagger/screens/home_screen.dart';
import 'package:gpx_photo_geotagger/state/app_controller.dart';
import 'package:gpx_photo_geotagger/state/photo_geotag_controller.dart';
import 'package:gpx_photo_geotagger/state/track_recorder_controller.dart';

void main() {
  testWidgets('renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(
          controller: PhotoGeotagController.preview(),
          appController: AppController(),
          trackRecorderController: TrackRecorderController(),
        ),
      ),
    );

    expect(find.text('写入位置'), findsOneWidget);
    expect(find.text('选择轨迹'), findsOneWidget);
    expect(find.text('选择照片'), findsOneWidget);
    expect(find.text('开始写入'), findsOneWidget);
  });
}
