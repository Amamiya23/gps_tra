import 'geo_match.dart';

class ProcessResult {
  const ProcessResult({
    required this.photoName,
    required this.success,
    required this.message,
    this.location,
  });

  final String photoName;
  final bool success;
  final String message;
  final GeoMatch? location;
}
