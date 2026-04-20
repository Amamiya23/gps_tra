import 'recorded_track_point.dart';

class RecordingDraft {
  const RecordingDraft({
    required this.sessionId,
    required this.startedAt,
    required this.elapsedSeconds,
    required this.pointCount,
    required this.points,
  });

  final String sessionId;
  final DateTime startedAt;
  final int elapsedSeconds;
  final int pointCount;
  final List<RecordedTrackPoint> points;

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'startedAt': startedAt.toIso8601String(),
      'elapsedSeconds': elapsedSeconds,
      'pointCount': pointCount,
      'points': points.map((item) => item.toJson()).toList(growable: false),
    };
  }

  factory RecordingDraft.fromJson(Map<String, dynamic> json) {
    final pointList = (json['points'] as List<dynamic>? ?? const [])
        .map((item) => RecordedTrackPoint.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    return RecordingDraft(
      sessionId: json['sessionId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      pointCount: (json['pointCount'] as num?)?.toInt() ?? pointList.length,
      points: pointList,
    );
  }
}
