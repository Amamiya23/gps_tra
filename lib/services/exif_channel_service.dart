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

  Future<void> writeGpsMetadata({
    required String source,
    required GeoMatch location,
    required DateTime gpsTimestamp,
  }) async {
    _ensureAndroid();

    final utcTime = gpsTimestamp.toUtc();

    await _channel.invokeMethod<void>(
      'writeGpsMetadata',
      <String, dynamic>{
        'source': source,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'altitude': location.altitude,
        'gpsDateStamp': _formatGpsDateStamp(utcTime),
        'gpsTimeStamp': _formatGpsTimeStamp(utcTime),
      },
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

    return DateTime.utc(
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
