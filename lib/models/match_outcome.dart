import 'geo_match.dart';

class MatchOutcome {
  const MatchOutcome({
    required this.reason,
    this.location,
    this.adjustedPhotoTime,
  });

  final String reason;
  final GeoMatch? location;
  final DateTime? adjustedPhotoTime;

  bool get matched => location != null;
}
