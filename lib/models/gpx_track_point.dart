class GpxTrackPoint {
  const GpxTrackPoint({
    required this.latitude,
    required this.longitude,
    required this.time,
    this.altitude,
  });

  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime time;
}
