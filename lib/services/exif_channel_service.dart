import 'dart:io';

import 'package:flutter/services.dart';

import '../models/geo_match.dart';
import '../models/photo_metadata.dart';

class ExifChannelService {
  static const MethodChannel _channel =
      MethodChannel('gpx_photo_geotagger/exif');

  Future<PhotoMetadata> readMetadata(String source) async {
    _ensureAndroid();

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'readMetadata',
      <String, dynamic>{'source': source},
    );

    final rawOriginalDate = result?['rawOriginalDate'] as String?;
    final hasGps = (result?['hasGps'] as bool?) ?? false;

    return PhotoMetadata(
      rawOriginalDate: rawOriginalDate,
      originalDate: _parseExifDate(rawOriginalDate),
      hasGps: hasGps,
    );
  }

  Future<List<PickedPhotoSource>> pickWritablePhotos() async {
    _ensureAndroid();

    final result = await _channel.invokeListMethod<dynamic>('pickWritablePhotos');
    return (result ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (item) => PickedPhotoSource(
            source: item['source'] as String,
            name: item['name'] as String,
          ),
        )
        .toList(growable: false);
  }

  Future<ExifWriteResult> writeGpsMetadata({
    required String source,
    required GeoMatch location,
    required DateTime gpsTimestamp,
    required String exportFolderName,
    required String exportFileSuffix,
    required bool writeToOriginal,
  }) async {
    _ensureAndroid();

    final utcTime = gpsTimestamp.toUtc();

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'writeGpsMetadata',
      <String, dynamic>{
        'source': source,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'altitude': location.altitude,
        'gpsDateStamp': _formatGpsDateStamp(utcTime),
        'gpsTimeStamp': _formatGpsTimeStamp(utcTime),
        'exportFolderName': exportFolderName,
        'exportFileSuffix': exportFileSuffix,
        'writeToOriginal': writeToOriginal,
      },
    );

    return ExifWriteResult(
      target: result?['target'] as String?,
      wroteToOriginal: (result?['wroteToOriginal'] as bool?) ?? false,
    );
  }

  DateTime? _parseExifDate(String? raw) {
    if (raw == null) {
      return null;
    }

    final match = RegExp(
      r'^(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})$',
    ).firstMatch(raw.trim());

    if (match == null) {
      return null;
    }

    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }

  String _formatGpsDateStamp(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}:$month:$day';
  }

  String _formatGpsTimeStamp(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  void _ensureAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前版本只支持 Android。');
    }
  }
}

class PickedPhotoSource {
  const PickedPhotoSource({
    required this.source,
    required this.name,
  });

  final String source;
  final String name;
}

class ExifWriteResult {
  const ExifWriteResult({
    required this.target,
    required this.wroteToOriginal,
  });

  final String? target;
  final bool wroteToOriginal;
}
