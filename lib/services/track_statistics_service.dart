import 'dart:math' as math;

import '../models/recorded_track_point.dart';

class TrackStatistics {
  const TrackStatistics({
    required this.distanceMeters,
    required this.averageSpeedMps,
    required this.averageSampleIntervalSeconds,
    required this.averageAccuracyMeters,
    required this.samplingQualityLabel,
  });

  final double distanceMeters;
  final double averageSpeedMps;
  final double averageSampleIntervalSeconds;
  final double? averageAccuracyMeters;
  final String samplingQualityLabel;
}

class TrackStatisticsService {
  const TrackStatisticsService();

  TrackStatistics calculate({
    required List<RecordedTrackPoint> points,
    required Duration duration,
  }) {
    if (points.length < 2) {
      return const TrackStatistics(
        distanceMeters: 0,
        averageSpeedMps: 0,
        averageSampleIntervalSeconds: 0,
        averageAccuracyMeters: null,
        samplingQualityLabel: '不足',
      );
    }

    var distanceMeters = 0.0;
    var intervalSecondsTotal = 0.0;
    var intervalCount = 0;
    var accuracyTotal = 0.0;
    var accuracyCount = 0;

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      distanceMeters += _distanceBetween(previous, current);

      final interval = current.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
      if (interval > 0) {
        intervalSecondsTotal += interval;
        intervalCount += 1;
      }
    }

    for (final point in points) {
      if (point.accuracy != null) {
        accuracyTotal += point.accuracy!;
        accuracyCount += 1;
      }
    }

    final averageInterval = intervalCount == 0 ? 0.0 : intervalSecondsTotal / intervalCount;
    final averageAccuracy = accuracyCount == 0 ? null : accuracyTotal / accuracyCount;
    final averageSpeed = duration.inSeconds == 0 ? 0.0 : distanceMeters / duration.inSeconds;

    return TrackStatistics(
      distanceMeters: distanceMeters,
      averageSpeedMps: averageSpeed,
      averageSampleIntervalSeconds: averageInterval,
      averageAccuracyMeters: averageAccuracy,
      samplingQualityLabel: _qualityLabel(
        averageIntervalSeconds: averageInterval,
        averageAccuracyMeters: averageAccuracy,
        pointCount: points.length,
      ),
    );
  }

  double _distanceBetween(RecordedTrackPoint a, RecordedTrackPoint b) {
    const earthRadius = 6371000.0;
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final deltaLat = _toRadians(b.latitude - a.latitude);
    final deltaLon = _toRadians(b.longitude - a.longitude);

    final haversine = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * math.pi / 180;

  String _qualityLabel({
    required double averageIntervalSeconds,
    required double? averageAccuracyMeters,
    required int pointCount,
  }) {
    if (pointCount < 5) {
      return '不足';
    }
    if (averageIntervalSeconds <= 8 && (averageAccuracyMeters == null || averageAccuracyMeters <= 15)) {
      return '高';
    }
    if (averageIntervalSeconds <= 15 && (averageAccuracyMeters == null || averageAccuracyMeters <= 30)) {
      return '中';
    }
    return '低';
  }
}
