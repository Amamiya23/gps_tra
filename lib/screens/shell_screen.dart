import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gpx_track_point.dart';
import '../models/recorded_track_session.dart';
import '../state/app_controller.dart';
import '../state/photo_geotag_controller.dart';
import '../state/track_recorder_controller.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'track_recorder_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({
    super.key,
    required this.appController,
    required this.photoController,
    required this.trackRecorderController,
  });

  final AppController appController;
  final PhotoGeotagController photoController;
  final TrackRecorderController trackRecorderController;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.trackRecorderController.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.trackRecorderController.maybePromptInitialLocationPermission());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TrackRecorderScreen(
            controller: widget.trackRecorderController,
            appController: widget.appController,
            photoController: widget.photoController,
            onUseForGeotag: _useTrackForGeotag,
          ),
          HomeScreen(
            controller: widget.photoController,
            appController: widget.appController,
            trackRecorderController: widget.trackRecorderController,
          ),
          SettingsScreen(
            controller: widget.photoController,
            appController: widget.appController,
            trackRecorderController: widget.trackRecorderController,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: '记录轨迹',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: '写入照片',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '工具设置',
          ),
        ],
      ),
    );
  }

  Future<void> _useTrackForGeotag(RecordedTrackSession session) async {
    final points = await widget.trackRecorderController.loadSessionPoints(session.id);
    if (points.isEmpty) {
      return;
    }

    widget.photoController.loadTrackPoints(
      name: session.title,
      points: points
          .map(
            (point) => GpxTrackPoint(
              latitude: point.latitude,
              longitude: point.longitude,
              altitude: point.altitude,
              time: point.timestamp.toUtc(),
            ),
          )
          .toList(growable: false),
    );

    setState(() {
      _currentIndex = 1;
    });
  }
}
