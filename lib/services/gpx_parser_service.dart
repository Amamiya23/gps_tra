import 'dart:io';

import 'package:xml/xml.dart';

import '../models/gpx_track_point.dart';

class GpxParserService {
  Future<List<GpxTrackPoint>> parseFile(String path) async {
    final xmlContent = await File(path).readAsString();
    final document = XmlDocument.parse(xmlContent);
    final points = <GpxTrackPoint>[];

    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'trkpt') {
        continue;
      }

      final latitude = double.tryParse(element.getAttribute('lat') ?? '');
      final longitude = double.tryParse(element.getAttribute('lon') ?? '');
      final timeText = _childText(element, 'time');
      if (latitude == null || longitude == null || timeText == null) {
        continue;
      }

      final parsedTime = DateTime.tryParse(timeText)?.toUtc();
      if (parsedTime == null) {
        continue;
      }

      points.add(
        GpxTrackPoint(
          latitude: latitude,
          longitude: longitude,
          altitude: double.tryParse(_childText(element, 'ele') ?? ''),
          time: parsedTime,
        ),
      );
    }

    points.sort((a, b) => a.time.compareTo(b.time));

    if (points.isEmpty) {
      throw const FormatException('GPX 中没有可用的轨迹点。');
    }

    return points;
  }

  String? _childText(XmlElement parent, String localName) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.name.local == localName) {
        final value = child.innerText.trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }
}
