class RecordedTrackSession {
  const RecordedTrackSession({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.durationSeconds,
    required this.pointCount,
    required this.stateLabel,
    this.distanceMeters = 0,
    this.averageSpeedMps = 0,
    this.averageSampleIntervalSeconds = 0,
    this.averageAccuracyMeters,
    this.samplingQualityLabel = '未知',
    this.endedAt,
    this.exportedGpxPath,
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int pointCount;
  final String stateLabel;
  final double distanceMeters;
  final double averageSpeedMps;
  final double averageSampleIntervalSeconds;
  final double? averageAccuracyMeters;
  final String samplingQualityLabel;
  final String? exportedGpxPath;

  Duration get duration => Duration(seconds: durationSeconds);

  RecordedTrackSession copyWith({
    String? title,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    int? pointCount,
    String? stateLabel,
    double? distanceMeters,
    double? averageSpeedMps,
    double? averageSampleIntervalSeconds,
    double? averageAccuracyMeters,
    String? samplingQualityLabel,
    String? exportedGpxPath,
    bool clearExportedPath = false,
  }) {
    return RecordedTrackSession(
      id: id,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pointCount: pointCount ?? this.pointCount,
      stateLabel: stateLabel ?? this.stateLabel,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      averageSpeedMps: averageSpeedMps ?? this.averageSpeedMps,
      averageSampleIntervalSeconds:
          averageSampleIntervalSeconds ?? this.averageSampleIntervalSeconds,
      averageAccuracyMeters: averageAccuracyMeters ?? this.averageAccuracyMeters,
      samplingQualityLabel: samplingQualityLabel ?? this.samplingQualityLabel,
      exportedGpxPath: clearExportedPath
          ? null
          : exportedGpxPath ?? this.exportedGpxPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'pointCount': pointCount,
      'stateLabel': stateLabel,
      'distanceMeters': distanceMeters,
      'averageSpeedMps': averageSpeedMps,
      'averageSampleIntervalSeconds': averageSampleIntervalSeconds,
      'averageAccuracyMeters': averageAccuracyMeters,
      'samplingQualityLabel': samplingQualityLabel,
      'exportedGpxPath': exportedGpxPath,
    };
  }

  factory RecordedTrackSession.fromJson(Map<String, dynamic> json) {
    return RecordedTrackSession(
      id: json['id'] as String,
      title: json['title'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      pointCount: (json['pointCount'] as num?)?.toInt() ?? 0,
      stateLabel: json['stateLabel'] as String? ?? '已保存',
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      averageSpeedMps: (json['averageSpeedMps'] as num?)?.toDouble() ?? 0,
      averageSampleIntervalSeconds:
          (json['averageSampleIntervalSeconds'] as num?)?.toDouble() ?? 0,
      averageAccuracyMeters:
          (json['averageAccuracyMeters'] as num?)?.toDouble(),
      samplingQualityLabel: json['samplingQualityLabel'] as String? ?? '未知',
      exportedGpxPath: json['exportedGpxPath'] as String?,
    );
  }
}
