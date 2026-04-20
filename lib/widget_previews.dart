import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'state/app_controller.dart';
import 'state/photo_geotag_controller.dart';
import 'state/track_recorder_controller.dart';

@Preview(name: 'Home Screen')
Widget previewHomeScreen() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: HomeScreen(
      controller: PhotoGeotagController.preview(),
      appController: AppController(),
      trackRecorderController: TrackRecorderController(),
    ),
  );
}
