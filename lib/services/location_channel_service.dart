import 'dart:async';

import 'package:flutter/services.dart';

import '../models/recorded_track_point.dart';
import '../models/track_recording_state.dart';

class RecorderStatusSnapshot {
  const RecorderStatusSnapshot({
    required this.state,
    required this.elapsed,
    required this.pointCount,
    required this.locationPermissionGranted,
    required this.backgroundPermissionGranted,
    required this.locationEnabled,
    this.startedAt,
    this.sessionId,
    this.lastLatitude,
    this.lastLongitude,
    this.lastAltitude,
    this.lastAccuracy,
    this.lastSpeed,
    this.lastTimestamp,
  });

  final TrackRecordingState state;
  final Duration elapsed;
  final int pointCount;
  final bool locationPermissionGranted;
  final bool backgroundPermissionGranted;
  final bool locationEnabled;
  final DateTime? startedAt;
  final String? sessionId;
  final double? lastLatitude;
  final double? lastLongitude;
  final double? lastAltitude;
  final double? lastAccuracy;
  final double? lastSpeed;
  final DateTime? lastTimestamp;

  factory RecorderStatusSnapshot.fromMap(Map<Object?, Object?>? map) {
    final data = map ?? const {};
    return RecorderStatusSnapshot(
      state: _stateFromString(data['state'] as String? ?? 'idle'),
      elapsed: Duration(seconds: ((data['elapsedSeconds'] as num?) ?? 0).toInt()),
      pointCount: ((data['pointCount'] as num?) ?? 0).toInt(),
      locationPermissionGranted: (data['locationPermissionGranted'] as bool?) ?? false,
      backgroundPermissionGranted: (data['backgroundPermissionGranted'] as bool?) ?? false,
      locationEnabled: (data['locationEnabled'] as bool?) ?? false,
      startedAt: _dateTimeFromMillis(data['startedAtMillis']),
      sessionId: data['sessionId'] as String?,
      lastLatitude: (data['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (data['lastLongitude'] as num?)?.toDouble(),
      lastAltitude: (data['lastAltitude'] as num?)?.toDouble(),
      lastAccuracy: (data['lastAccuracy'] as num?)?.toDouble(),
      lastSpeed: (data['lastSpeed'] as num?)?.toDouble(),
      lastTimestamp: _dateTimeFromMillis(data['lastTimestampMillis']),
    );
  }

  static DateTime? _dateTimeFromMillis(Object? value) {
    final millis = (value as num?)?.toInt();
    if (millis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static TrackRecordingState _stateFromString(String value) {
    switch (value) {
      case 'recording':
        return TrackRecordingState.recording;
      case 'paused':
        return TrackRecordingState.paused;
      default:
        return TrackRecordingState.idle;
    }
  }
}

class RecorderStoppedSession {
  const RecorderStoppedSession({
    required this.sessionId,
    required this.startedAt,
    required this.endedAt,
    required this.elapsed,
    required this.pointCount,
    required this.points,
  });

  final String? sessionId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final Duration elapsed;
  final int pointCount;
  final List<RecordedTrackPoint> points;

  factory RecorderStoppedSession.fromMap(Map<Object?, Object?>? map) {
    final data = map ?? const {};
    return RecorderStoppedSession(
      sessionId: data['sessionId'] as String?,
      startedAt: RecorderStatusSnapshot._dateTimeFromMillis(data['startedAtMillis']),
      endedAt: RecorderStatusSnapshot._dateTimeFromMillis(data['endedAtMillis']),
      elapsed: Duration(seconds: ((data['elapsedSeconds'] as num?) ?? 0).toInt()),
      pointCount: ((data['pointCount'] as num?) ?? 0).toInt(),
      points: ((data['points'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<Object?, Object?>>()
          .map(
            (item) => RecordedTrackPoint(
              sessionId: item['sessionId'] as String,
              latitude: (item['latitude'] as num).toDouble(),
              longitude: (item['longitude'] as num).toDouble(),
              timestamp: DateTime.parse(item['timestamp'] as String),
              altitude: (item['altitude'] as num?)?.toDouble(),
              accuracy: (item['accuracy'] as num?)?.toDouble(),
              speed: (item['speed'] as num?)?.toDouble(),
            ),
          )
          .toList(growable: false),
    );
  }
}

class LocationChannelService {
  static const MethodChannel _channel = MethodChannel('gpx_photo_geotagger/track_recorder');
  static const EventChannel _events = EventChannel('gpx_photo_geotagger/track_recorder_events');

  Stream<RecorderStatusSnapshot> statusStream() {
    return _events
        .receiveBroadcastStream()
        .map((event) => RecorderStatusSnapshot.fromMap(event as Map<Object?, Object?>?));
  }

  Future<RecorderStatusSnapshot> requestPermissions() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('requestPermissions');
    return RecorderStatusSnapshot.fromMap(result);
  }

  Future<RecorderStatusSnapshot> getStatus() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('getStatus');
    return RecorderStatusSnapshot.fromMap(result);
  }

  Future<RecorderStatusSnapshot> refreshStatus() async {
    return getStatus();
  }

  Future<RecorderStatusSnapshot> startRecording(int intervalMillis) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'startRecording',
      {'intervalMillis': intervalMillis},
    );
    return RecorderStatusSnapshot.fromMap(result);
  }

  Future<RecorderStatusSnapshot> pauseRecording() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('pauseRecording');
    return RecorderStatusSnapshot.fromMap(result);
  }

  Future<RecorderStatusSnapshot> resumeRecording() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('resumeRecording');
    return RecorderStatusSnapshot.fromMap(result);
  }

  Future<RecorderStoppedSession> stopRecording() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('stopRecording');
    return RecorderStoppedSession.fromMap(result);
  }

  Future<List<RecordedTrackPoint>> getRecordedPoints([String? sessionId]) async {
    final result = await _channel.invokeListMethod<Object?>('getRecordedPoints', {
      if (sessionId != null) 'sessionId': sessionId,
    });
    return (result ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => RecordedTrackPoint(
            sessionId: item['sessionId'] as String,
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
            timestamp: DateTime.parse(item['timestamp'] as String),
            altitude: (item['altitude'] as num?)?.toDouble(),
            accuracy: (item['accuracy'] as num?)?.toDouble(),
            speed: (item['speed'] as num?)?.toDouble(),
          ),
        )
        .toList(growable: false);
  }
}
