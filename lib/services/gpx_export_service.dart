import '../models/recorded_track_point.dart';

class GpxExportService {
  String buildGpx({
    required String name,
    required List<RecordedTrackPoint> points,
  }) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<gpx version="1.1" creator="TrackWrite" xmlns="http://www.topografix.com/GPX/1/1">')
      ..writeln('  <trk>')
      ..writeln('    <name>${_escapeXml(name)}</name>')
      ..writeln('    <trkseg>');

    for (final point in points) {
      buffer.writeln(
        '      <trkpt lat="${point.latitude}" lon="${point.longitude}">',
      );
      if (point.altitude != null) {
        buffer.writeln('        <ele>${point.altitude}</ele>');
      }
      buffer.writeln('        <time>${point.timestamp.toUtc().toIso8601String()}</time>');
      buffer.writeln('      </trkpt>');
    }

    buffer
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');

    return buffer.toString();
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
