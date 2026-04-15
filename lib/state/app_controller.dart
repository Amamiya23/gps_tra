import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/gpx_track_point.dart';
import '../models/process_result.dart';
import '../models/selected_photo.dart';
import '../services/exif_channel_service.dart';
import '../services/gpx_parser_service.dart';
import '../services/location_match_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    GpxParserService? gpxParser,
    ExifChannelService? exifService,
    LocationMatchService? matchService,
  })  : _gpxParser = gpxParser ?? GpxParserService(),
        _exifService = exifService ?? ExifChannelService(),
        _matchService =
            matchService ?? const LocationMatchService(maxGap: Duration(minutes: 5));

  final GpxParserService _gpxParser;
  final ExifChannelService _exifService;
  final LocationMatchService _matchService;

  List<GpxTrackPoint> _trackPoints = const [];
  List<SelectedPhoto> _photos = const [];
  List<ProcessResult> _results = const [];
  String? _gpxFileName;
  bool _isBusy = false;
  double _progress = 0;
  String _statusText = '等待选择 GPX 和 JPG';
  String _offsetInput = '00:00:00';
  Duration _offset = Duration.zero;
  String? _pendingMessage;

  List<GpxTrackPoint> get trackPoints => _trackPoints;
  List<SelectedPhoto> get photos => _photos;
  List<ProcessResult> get results => _results;
  String? get gpxFileName => _gpxFileName;
  bool get isBusy => _isBusy;
  double get progress => _progress;
  String get statusText => _statusText;
  String get offsetInput => _offsetInput;
  Duration get offset => _offset;

  int get matchedPreviewCount =>
      _photos.where((photo) => photo.preview?.matched == true).length;

  int get writablePhotoCount => _photos.where((photo) => photo.canWrite).length;

  bool get canProcess =>
      !_isBusy && _trackPoints.isNotEmpty && _photos.isNotEmpty && writablePhotoCount > 0;

  String? takeMessage() {
    final value = _pendingMessage;
    _pendingMessage = null;
    return value;
  }

  Future<void> pickGpx() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['gpx'],
    );
    if (result == null) {
      return;
    }

    final picked = result.files.single;
    final path = picked.path;
    if (path == null) {
      _setMessage('无法读取 GPX 文件路径。');
      notifyListeners();
      return;
    }

    await _runBusy('解析 GPX 中...', () async {
      _trackPoints = List.unmodifiable(await _gpxParser.parseFile(path));
      _gpxFileName = picked.name;
      _results = const [];
      _statusText = '已导入 GPX，共 ${_trackPoints.length} 个轨迹点';
      _refreshPreviews();
      _setMessage('GPX 导入完成。');
    });
  }

  Future<void> pickPhotos() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'JPG', 'JPEG'],
    );
    if (result == null) {
      return;
    }

    await _runBusy('读取照片元数据中...', () async {
      final selected = <SelectedPhoto>[];
      final seenSources = <String>{};

      for (var index = 0; index < result.files.length; index++) {
        final picked = result.files[index];
        final source = picked.identifier ?? picked.path;
        _progress = (index + 1) / result.files.length;
        _statusText = '读取元数据 ${index + 1}/${result.files.length}: ${picked.name}';
        notifyListeners();

        if (source == null || source.isEmpty) {
          selected.add(
            SelectedPhoto(
              name: picked.name,
              source: '',
              cachePath: picked.path,
              loadError: '文件没有可写入的来源标识。',
            ),
          );
          continue;
        }

        if (!seenSources.add(source)) {
          continue;
        }

        try {
          final metadata = await _exifService.readMetadata(source);
          selected.add(
            SelectedPhoto(
              name: picked.name,
              source: source,
              cachePath: picked.path,
              rawOriginalDate: metadata.rawOriginalDate,
              originalDate: metadata.originalDate,
              hasGps: metadata.hasGps,
            ),
          );
        } catch (error) {
          selected.add(
            SelectedPhoto(
              name: picked.name,
              source: source,
              cachePath: picked.path,
              loadError: '读取 EXIF 失败: $error',
            ),
          );
        }
      }

      selected.sort((left, right) {
        if (left.originalDate == null && right.originalDate == null) {
          return left.name.compareTo(right.name);
        }
        if (left.originalDate == null) {
          return 1;
        }
        if (right.originalDate == null) {
          return -1;
        }
        return left.originalDate!.compareTo(right.originalDate!);
      });

      _photos = List.unmodifiable(selected);
      _results = const [];
      _statusText = '已选择 ${_photos.length} 张 JPG';
      _refreshPreviews();
      _setMessage('照片导入完成。');
    });
  }

  void updateOffset(String input) {
    final parsed = _parseOffset(input);
    if (parsed == null) {
      _setMessage('偏移格式无效，请使用类似 -08:00:00 或 00:15:30。');
      notifyListeners();
      return;
    }

    _offsetInput = input;
    _offset = parsed;
    _refreshPreviews();
    _setMessage('时间偏移已更新。');
    notifyListeners();
  }

  Future<void> processPhotos() async {
    if (!canProcess) {
      _setMessage('请先选择 GPX 和可处理的 JPG。');
      notifyListeners();
      return;
    }

    await _runBusy('准备写入 GPS EXIF...', () async {
      final output = <ProcessResult>[];
      final writablePhotos = _photos.where((photo) => photo.canWrite).toList();

      for (var index = 0; index < writablePhotos.length; index++) {
        final photo = writablePhotos[index];
        final preview = photo.preview;
        _progress = (index + 1) / writablePhotos.length;
        _statusText = '写入 ${index + 1}/${writablePhotos.length}: ${photo.name}';
        notifyListeners();

        if (preview == null || !preview.matched || preview.location == null) {
          output.add(
            ProcessResult(
              photoName: photo.name,
              success: false,
              message: preview?.reason ?? '没有匹配到可写入的位置',
            ),
          );
          continue;
        }

        try {
          await _exifService.writeGpsMetadata(
            source: photo.source,
            location: preview.location!,
            gpsTimestamp: preview.adjustedPhotoTime ?? preview.location!.timestamp,
          );
          output.add(
            ProcessResult(
              photoName: photo.name,
              success: true,
              message: 'GPS EXIF 写入成功',
              location: preview.location,
            ),
          );
        } catch (error) {
          output.add(
            ProcessResult(
              photoName: photo.name,
              success: false,
              message: '写入失败: $error',
              location: preview.location,
            ),
          );
        }
      }

      _results = List.unmodifiable(output);
      final successCount = _results.where((item) => item.success).length;
      _statusText = '处理完成，成功 $successCount / ${_results.length}';
      _setMessage('批量写入完成。');
    });
  }

  void _refreshPreviews() {
    if (_photos.isEmpty) {
      return;
    }

    if (_trackPoints.isEmpty) {
      _photos = List.unmodifiable(
        _photos
            .map((photo) => photo.copyWith(clearPreview: true))
            .toList(growable: false),
      );
      return;
    }

    _photos = List.unmodifiable(
      _photos
          .map(
            (photo) => photo.copyWith(
              preview: _matchService.match(
                photoTime: photo.originalDate,
                offset: _offset,
                trackPoints: _trackPoints,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Duration? _parseOffset(String input) {
    final match = RegExp(r'^([+-])?(\d{1,2}):(\d{2}):(\d{2})$').firstMatch(
      input.trim(),
    );
    if (match == null) {
      return null;
    }

    final negative = match.group(1) == '-';
    final hours = int.parse(match.group(2)!);
    final minutes = int.parse(match.group(3)!);
    final seconds = int.parse(match.group(4)!);
    if (minutes > 59 || seconds > 59) {
      return null;
    }

    final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
    return negative ? -duration : duration;
  }

  Future<void> _runBusy(String status, Future<void> Function() action) async {
    _isBusy = true;
    _progress = 0;
    _statusText = status;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _statusText = '发生错误';
      _setMessage(error.toString());
    } finally {
      _isBusy = false;
      _progress = 0;
      notifyListeners();
    }
  }

  void _setMessage(String message) {
    _pendingMessage = message;
  }
}
