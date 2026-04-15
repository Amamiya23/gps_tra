class PhotoMetadata {
  const PhotoMetadata({
    this.originalDate,
    this.rawOriginalDate,
    required this.hasGps,
  });

  final DateTime? originalDate;
  final String? rawOriginalDate;
  final bool hasGps;
}
