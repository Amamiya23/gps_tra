class RecordedTrackPoint {
  const RecordedTrackPoint({
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.accuracy,
    this.speed,
  });

  final String sessionId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitude;
  final double? accuracy;
  final double? speed;

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
    };
  }

  factory RecordedTrackPoint.fromJson(Map<String, dynamic> json) {
    return RecordedTrackPoint(
      sessionId: json['sessionId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
    );
  }
}
