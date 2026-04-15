import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'state/app_controller.dart';

void main() {
  runApp(const GpxPhotoGeotaggerApp());
}

class GpxPhotoGeotaggerApp extends StatefulWidget {
  const GpxPhotoGeotaggerApp({super.key});

  @override
  State<GpxPhotoGeotaggerApp> createState() => _GpxPhotoGeotaggerAppState();
}

class _GpxPhotoGeotaggerAppState extends State<GpxPhotoGeotaggerApp> {
  final AppController _controller = AppController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            return MaterialApp(
              title: 'GPX 照片定位器',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(lightDynamic),
              darkTheme: AppTheme.dark(darkDynamic),
              themeMode: _controller.themeMode,
              home: HomeScreen(controller: _controller),
            );
          },
        );
      },
    );
  }
}
