import 'dart:math';

import '../models/geo_match.dart';
import '../models/gpx_track_point.dart';
import '../models/match_outcome.dart';

class LocationMatchService {
  const LocationMatchService({this.maxGap = const Duration(minutes: 5)});

  final Duration maxGap;

  MatchOutcome match({
    required DateTime? photoTime,
    required Duration offset,
    required List<GpxTrackPoint> trackPoints,
  }) {
    if (photoTime == null) {
      return const MatchOutcome(reason: '照片没有可用的拍摄时间');
    }
    if (trackPoints.isEmpty) {
      return const MatchOutcome(reason: 'GPX 轨迹为空');
    }

    final adjustedTime = photoTime.add(offset);
    final firstPoint = trackPoints.first;
    final lastPoint = trackPoints.last;

    if (adjustedTime.isBefore(firstPoint.time)) {
      final gap = firstPoint.time.difference(adjustedTime);
      if (gap > maxGap) {
        return MatchOutcome(
          reason: '照片时间早于轨迹开始 ${gap.inMinutes} 分钟以上',
          adjustedPhotoTime: adjustedTime,
        );
      }
      return MatchOutcome(
        reason: '使用轨迹起点',
        adjustedPhotoTime: adjustedTime,
        location: GeoMatch(
          latitude: firstPoint.latitude,
          longitude: firstPoint.longitude,
          altitude: firstPoint.altitude,
          timestamp: firstPoint.time,
        ),
      );
    }

    if (adjustedTime.isAfter(lastPoint.time)) {
      final gap = adjustedTime.difference(lastPoint.time);
      if (gap > maxGap) {
        return MatchOutcome(
          reason: '照片时间晚于轨迹结束 ${gap.inMinutes} 分钟以上',
          adjustedPhotoTime: adjustedTime,
        );
      }
      return MatchOutcome(
        reason: '使用轨迹终点',
        adjustedPhotoTime: adjustedTime,
        location: GeoMatch(
          latitude: lastPoint.latitude,
          longitude: lastPoint.longitude,
          altitude: lastPoint.altitude,
          timestamp: lastPoint.time,
        ),
      );
    }

    final upperIndex = _firstIndexAtOrAfter(trackPoints, adjustedTime);
    if (upperIndex == 0) {
      return MatchOutcome(
        reason: '使用轨迹起点',
        adjustedPhotoTime: adjustedTime,
        location: GeoMatch(
          latitude: firstPoint.latitude,
          longitude: firstPoint.longitude,
          altitude: firstPoint.altitude,
          timestamp: firstPoint.time,
        ),
      );
    }

    final next = trackPoints[upperIndex];
    final previous = trackPoints[upperIndex - 1];

    if (adjustedTime.isAtSameMomentAs(previous.time)) {
      return MatchOutcome(
        reason: '命中轨迹点',
        adjustedPhotoTime: adjustedTime,
        location: GeoMatch(
          latitude: previous.latitude,
          longitude: previous.longitude,
          altitude: previous.altitude,
          timestamp: previous.time,
        ),
      );
    }

    if (adjustedTime.isAtSameMomentAs(next.time)) {
      return MatchOutcome(
        reason: '命中轨迹点',
        adjustedPhotoTime: adjustedTime,
        location: GeoMatch(
          latitude: next.latitude,
          longitude: next.longitude,
          altitude: next.altitude,
          timestamp: next.time,
        ),
      );
    }

    final nearestGap = min(
      adjustedTime.difference(previous.time).inSeconds.abs(),
      next.time.difference(adjustedTime).inSeconds.abs(),
    );
    if (nearestGap > maxGap.inSeconds) {
      return MatchOutcome(
        reason: '最近轨迹点超过 ${maxGap.inMinutes} 分钟',
        adjustedPhotoTime: adjustedTime,
      );
    }

    final totalSpanMs =
        next.time.millisecondsSinceEpoch - previous.time.millisecondsSinceEpoch;
    if (totalSpanMs <= 0) {
      return MatchOutcome(
        reason: '使用前一个轨迹点',
        adjustedPhotoTime: adjustedTime,
        location: GeoMatch(
          latitude: previous.latitude,
          longitude: previous.longitude,
          altitude: previous.altitude,
          timestamp: previous.time,
        ),
      );
    }

    final currentOffsetMs =
        adjustedTime.millisecondsSinceEpoch - previous.time.millisecondsSinceEpoch;
    final ratio = currentOffsetMs / totalSpanMs;

    return MatchOutcome(
      reason: '线性插值匹配',
      adjustedPhotoTime: adjustedTime,
      location: GeoMatch(
        latitude: _interpolate(previous.latitude, next.latitude, ratio),
        longitude: _interpolate(previous.longitude, next.longitude, ratio),
        altitude: _interpolateNullable(previous.altitude, next.altitude, ratio),
        timestamp: adjustedTime,
      ),
    );
  }

  int _firstIndexAtOrAfter(List<GpxTrackPoint> points, DateTime value) {
    var low = 0;
    var high = points.length - 1;
    while (low < high) {
      final mid = low + ((high - low) ~/ 2);
      if (points[mid].time.isBefore(value)) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  double _interpolate(double start, double end, double ratio) {
    return start + ((end - start) * ratio);
  }

  double? _interpolateNullable(double? start, double? end, double ratio) {
    if (start == null || end == null) {
      return start ?? end;
    }
    return _interpolate(start, end, ratio);
  }
}
