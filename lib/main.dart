import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/shell_screen.dart';
import 'state/app_controller.dart';
import 'state/photo_geotag_controller.dart';
import 'state/track_recorder_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appController = AppController();
  final photoController = PhotoGeotagController();
  final trackRecorderController = TrackRecorderController();

  await Future.wait([
    appController.initialize(),
    photoController.initialize(),
    trackRecorderController.initialize(),
  ]);

  runApp(
    GpxPhotoGeotaggerApp(
      appController: appController,
      photoController: photoController,
      trackRecorderController: trackRecorderController,
    ),
  );
}

class GpxPhotoGeotaggerApp extends StatefulWidget {
  const GpxPhotoGeotaggerApp({
    super.key,
    required this.appController,
    required this.photoController,
    required this.trackRecorderController,
  });

  final AppController appController;
  final PhotoGeotagController photoController;
  final TrackRecorderController trackRecorderController;

  @override
  State<GpxPhotoGeotaggerApp> createState() => _GpxPhotoGeotaggerAppState();
}

class _GpxPhotoGeotaggerAppState extends State<GpxPhotoGeotaggerApp> {
  late final AppController _appController;
  late final PhotoGeotagController _photoController;
  late final TrackRecorderController _trackRecorderController;

  @override
  void initState() {
    super.initState();
    _appController = widget.appController;
    _photoController = widget.photoController;
    _trackRecorderController = widget.trackRecorderController;
  }

  @override
  void dispose() {
    _appController.dispose();
    _photoController.dispose();
    _trackRecorderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appController,
      builder: (context, _) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            return MaterialApp(
              title: 'GPX 照片定位器',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(lightDynamic),
              darkTheme: AppTheme.dark(darkDynamic),
              themeMode: _appController.themeMode,
              home: ShellScreen(
                appController: _appController,
                photoController: _photoController,
                trackRecorderController: _trackRecorderController,
              ),
            );
          },
        );
      },
    );
  }
}
