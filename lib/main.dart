import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const GpxPhotoGeotaggerApp());
}

class GpxPhotoGeotaggerApp extends StatelessWidget {
  const GpxPhotoGeotaggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPX 照片定位器',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
