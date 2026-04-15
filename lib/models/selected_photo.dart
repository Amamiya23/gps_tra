import 'match_outcome.dart';

class SelectedPhoto {
  const SelectedPhoto({
    required this.name,
    required this.source,
    this.cachePath,
    this.rawOriginalDate,
    this.originalDate,
    this.hasGps = false,
    this.loadError,
    this.preview,
  });

  final String name;
  final String source;
  final String? cachePath;
  final String? rawOriginalDate;
  final DateTime? originalDate;
  final bool hasGps;
  final String? loadError;
  final MatchOutcome? preview;

  bool get canWrite => loadError == null && originalDate != null;

  SelectedPhoto copyWith({
    String? name,
    String? source,
    String? cachePath,
    String? rawOriginalDate,
    DateTime? originalDate,
    bool? hasGps,
    String? loadError,
    bool clearLoadError = false,
    MatchOutcome? preview,
    bool clearPreview = false,
  }) {
    return SelectedPhoto(
      name: name ?? this.name,
      source: source ?? this.source,
      cachePath: cachePath ?? this.cachePath,
      rawOriginalDate: rawOriginalDate ?? this.rawOriginalDate,
      originalDate: originalDate ?? this.originalDate,
      hasGps: hasGps ?? this.hasGps,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      preview: clearPreview ? null : (preview ?? this.preview),
    );
  }
}
