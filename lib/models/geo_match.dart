class GeoMatch {
  const GeoMatch({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
  });

  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime timestamp;
}
