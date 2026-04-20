import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/geo_match.dart';
import '../models/gpx_track_point.dart';
import '../models/match_outcome.dart';
import '../models/process_result.dart';
import '../models/selected_photo.dart';
import '../services/exif_channel_service.dart';
import '../services/gpx_parser_service.dart';
import '../services/location_match_service.dart';

class PhotoGeotagController extends ChangeNotifier {
  static const _offsetInputKey = 'photo.offset_input';
  static const _maxGapMinutesKey = 'photo.max_gap_minutes';
  static const _overwriteExistingGpsKey = 'photo.overwrite_existing_gps';
  static const _exportFolderNameKey = 'photo.export_folder_name';
  static const _exportFileSuffixKey = 'photo.export_file_suffix';
  static const _writeModeKey = 'photo.write_mode';
  static const _defaultExportFolderName = 'GPS Photo Geotagger';
  static const _defaultExportFileSuffix = '_gps_copy';

  PhotoGeotagController({
    GpxParserService? gpxParser,
    ExifChannelService? exifService,
    LocationMatchService? matchService,
  })  : _gpxParser = gpxParser ?? GpxParserService(),
        _exifService = exifService ?? ExifChannelService(),
        _matchService = matchService ??
            const LocationMatchService(maxGap: Duration(minutes: 5));

  PhotoGeotagController.preview()
      : _gpxParser = GpxParserService(),
        _exifService = ExifChannelService(),
        _matchService =
            const LocationMatchService(maxGap: Duration(minutes: 5)) {
    _trackPoints = List.unmodifiable([
      GpxTrackPoint(
        latitude: 31.230437,
        longitude: 121.473701,
        altitude: 12.5,
        time: DateTime.utc(2026, 4, 15, 8, 0, 0),
      ),
      GpxTrackPoint(
        latitude: 31.231120,
        longitude: 121.474520,
        altitude: 13.2,
        time: DateTime.utc(2026, 4, 15, 8, 1, 0),
      ),
    ]);
    _photos = List.unmodifiable([
      SelectedPhoto(
        name: 'IMG_20260415_080015.jpg',
        source: 'preview-1',
        rawOriginalDate: '2026:04:15 08:00:15',
        originalDate: DateTime.utc(2026, 4, 15, 8, 0, 15),
        preview: MatchOutcome(
          reason: '已匹配到最近轨迹点',
          adjustedPhotoTime: DateTime.utc(2026, 4, 15, 8, 0, 15),
          location: GeoMatch(
            latitude: 31.230437,
            longitude: 121.473701,
            altitude: 12.5,
            timestamp: DateTime.utc(2026, 4, 15, 8, 0, 0),
          ),
        ),
      ),
      SelectedPhoto(
        name: 'IMG_20260415_080315.jpg',
        source: 'preview-2',
        rawOriginalDate: '2026:04:15 08:03:15',
        originalDate: DateTime.utc(2026, 4, 15, 8, 3, 15),
        hasGps: true,
        preview: const MatchOutcome(reason: '超出最大时间差，未匹配到轨迹点'),
      ),
      const SelectedPhoto(
        name: 'IMG_20260415_080500.jpg',
        source: 'preview-3',
        loadError: '读取 EXIF 失败: 预览环境中不加载原始文件',
      ),
    ]);
    _results = List.unmodifiable([
      ProcessResult(
        photoName: 'IMG_20260415_080015.jpg',
        success: true,
        message: '位置信息写入成功',
        location: GeoMatch(
          latitude: 31.230437,
          longitude: 121.473701,
          altitude: 12.5,
          timestamp: DateTime.utc(2026, 4, 15, 8, 0, 0),
        ),
      ),
      const ProcessResult(
        photoName: 'IMG_20260415_080315.jpg',
        success: false,
        message: '未找到匹配的位置信息',
      ),
    ]);
    _gpxFileName = 'sample_track.gpx';
    _statusText = '预览模式，展示静态样例数据';
  }

  final GpxParserService _gpxParser;
  final ExifChannelService _exifService;
  LocationMatchService _matchService;
  SharedPreferences? _preferences;

  List<GpxTrackPoint> _trackPoints = const [];
  List<SelectedPhoto> _photos = const [];
  List<ProcessResult> _results = const [];
  String? _gpxFileName;
  bool _isBusy = false;
  double _progress = 0;
  int _currentProcessCount = 0;
  int _totalProcessCount = 0;
  String _statusText = '等待选择 GPX 和 JPG';
  String _offsetInput = '00:00:00';
  Duration _offset = Duration.zero;
  bool _overwriteExistingGps = true;
  String _exportFolderName = _defaultExportFolderName;
  String _exportFileSuffix = _defaultExportFileSuffix;
  bool _writeToOriginal = false;
  String? _pendingMessage;
  String? _temporaryDirectoryPath;

  List<GpxTrackPoint> get trackPoints => _trackPoints;
  List<SelectedPhoto> get photos => _photos;
  List<ProcessResult> get results => _results;
  String? get gpxFileName => _gpxFileName;
  bool get isBusy => _isBusy;
  double get progress => _progress;
  int get currentProcessCount => _currentProcessCount;
  int get totalProcessCount => _totalProcessCount;
  String get statusText => _statusText;
  String get offsetInput => _offsetInput;
  Duration get offset => _offset;
  int get maxGapMinutes => _matchService.maxGap.inMinutes;
  bool get overwriteExistingGps => _overwriteExistingGps;
  String get exportFolderName => _exportFolderName;
  String get exportFileSuffix => _exportFileSuffix;
  bool get writeToOriginal => _writeToOriginal;

  int get matchedPreviewCount =>
      _photos.where((photo) => photo.preview?.matched == true).length;
  int get writablePhotoCount => _photos.where(_canWritePhoto).length;
  int get photosWithGpsCount => _photos.where((photo) => photo.hasGps).length;
  bool get isReadyToProcess =>
      _trackPoints.isNotEmpty && _photos.isNotEmpty && writablePhotoCount > 0;
  bool get canProcess => !_isBusy && isReadyToProcess;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _temporaryDirectoryPath = (await getTemporaryDirectory()).path;
    _offsetInput = _preferences?.getString(_offsetInputKey) ?? _offsetInput;
    _offset = _parseOffset(_offsetInput) ?? Duration.zero;
    final storedMaxGapMinutes = _preferences?.getInt(_maxGapMinutesKey) ??
        _matchService.maxGap.inMinutes;
    _overwriteExistingGps = _preferences?.getBool(_overwriteExistingGpsKey) ??
        _overwriteExistingGps;
    _exportFolderName =
        _preferences?.getString(_exportFolderNameKey) ?? _exportFolderName;
    _exportFileSuffix =
        _preferences?.getString(_exportFileSuffixKey) ?? _exportFileSuffix;
    _writeToOriginal =
        (_preferences?.getString(_writeModeKey) ?? 'copy') == 'original';
    _matchService = LocationMatchService(
      maxGap: Duration(minutes: storedMaxGapMinutes.clamp(1, 30)),
    );
    unawaited(_clearStalePickerCache());
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_cleanupSelectedPhotoCaches(_photos));
    super.dispose();
  }

  String? takeMessage() {
    final value = _pendingMessage;
    _pendingMessage = null;
    return value;
  }

  void loadTrackPoints({
    required String name,
    required List<GpxTrackPoint> points,
  }) {
    _trackPoints = List.unmodifiable(points);
    _gpxFileName = name;
    _results = const [];
    _statusText = '已载入应用内轨迹，共 ${_trackPoints.length} 个轨迹点';
    _refreshPreviews();
    _setMessage('已选择应用内轨迹。');
    notifyListeners();
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
      try {
        _trackPoints = List.unmodifiable(await _gpxParser.parseFile(path));
        _gpxFileName = picked.name;
        _results = const [];
        _statusText = '已导入 GPX，共 ${_trackPoints.length} 个轨迹点';
        _refreshPreviews();
        _setMessage('GPX 导入完成。');
      } finally {
        await _deleteManagedTempFile(path);
      }
    });
  }

  Future<void> pickPhotos() async {
    final pickedItems = await _pickPhotoSources();

    if (pickedItems.isEmpty) {
      return;
    }

    await _runBusy('读取照片元数据中...', () async {
      final previousPhotos = _photos;
      final selected = <SelectedPhoto>[];
      final seenSources = <String>{};
      final retainedCachePaths = <String>{};

      _totalProcessCount = pickedItems.length;
      for (var index = 0; index < pickedItems.length; index++) {
        final picked = pickedItems[index];
        final readSource = picked.readSource;
        final source = picked.writeSource;
        _currentProcessCount = index + 1;
        _progress = (index + 1) / pickedItems.length;
        _statusText =
            '读取元数据 ${index + 1}/${pickedItems.length}: ${picked.name}';
        notifyListeners();

        if (source == null || source.isEmpty) {
          selected.add(
            SelectedPhoto(
              name: picked.name,
              source: '',
              cachePath: picked.cachePath,
              loadError: '文件没有可写入的来源标识。',
            ),
          );
          continue;
        }

        if (!seenSources.add(source)) {
          continue;
        }

        try {
          final metadata = await _exifService.readMetadata(readSource!);
          selected.add(
            SelectedPhoto(
              name: picked.name,
              source: source,
              cachePath: picked.cachePath,
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
              cachePath: picked.cachePath,
              loadError: '读取 EXIF 失败: $error',
            ),
          );
        } finally {
          final cachePath = picked.cachePath;
          if (cachePath != null && cachePath.isNotEmpty) {
            if (_shouldRetainCachePath(source: source, cachePath: cachePath)) {
              retainedCachePaths.add(cachePath);
            } else {
              await _deleteManagedTempFile(cachePath);
            }
          }
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
      await _cleanupSelectedPhotoCaches(previousPhotos);

      // 有些设备上 file_picker 只能返回缓存副本路径，这类文件要保留到本次会话结束。
      _photos = List.unmodifiable(
        _photos
            .map(
              (photo) => retainedCachePaths.contains(photo.cachePath)
                  ? photo
                  : photo.copyWith(cachePath: null),
            )
            .toList(growable: false),
      );
    });
  }

  String? updateSettings({
    required String offsetInput,
    required int maxGapMinutes,
    required bool overwriteExistingGps,
    String? exportFolderName,
    String? exportFileSuffix,
    bool? writeToOriginal,
  }) {
    final parsed = _parseOffset(offsetInput);
    if (parsed == null) {
      return '偏移格式无效，请使用类似 -08:00:00 或 00:15:30。';
    }
    final nextExportFolderName =
        _sanitizeExportFolderName(exportFolderName ?? _exportFolderName);
    if (nextExportFolderName.isEmpty) {
      return '导出目录名不能为空。';
    }
    final nextExportFileSuffix =
        _sanitizeExportFileSuffix(exportFileSuffix ?? _exportFileSuffix);
    if (nextExportFileSuffix.isEmpty) {
      return '文件后缀不能为空。';
    }

    _offsetInput = offsetInput.trim();
    _offset = parsed;
    _overwriteExistingGps = overwriteExistingGps;
    _exportFolderName = nextExportFolderName;
    _exportFileSuffix = nextExportFileSuffix;
    _writeToOriginal = writeToOriginal ?? _writeToOriginal;
    _matchService = LocationMatchService(
      maxGap: Duration(minutes: maxGapMinutes.clamp(1, 30)),
    );
    unawaited(_preferences?.setString(_offsetInputKey, _offsetInput));
    unawaited(_preferences?.setInt(_maxGapMinutesKey, this.maxGapMinutes));
    unawaited(
      _preferences?.setBool(_overwriteExistingGpsKey, _overwriteExistingGps),
    );
    unawaited(_preferences?.setString(_exportFolderNameKey, _exportFolderName));
    unawaited(_preferences?.setString(_exportFileSuffixKey, _exportFileSuffix));
    unawaited(_preferences?.setString(
        _writeModeKey, _writeToOriginal ? 'original' : 'copy'));
    _refreshPreviews();
    _setMessage('设置已更新。');
    notifyListeners();
    return null;
  }

  Future<void> processPhotos() async {
    if (!canProcess) {
      _setMessage('请先选择 GPX 和可处理的 JPG。');
      notifyListeners();
      return;
    }

    await _runBusy(_writeToOriginal ? '准备写回原图...' : '准备导出带 GPS 的照片副本...',
        () async {
      final output = <ProcessResult>[];
      final writablePhotos = _photos.where(_canWritePhoto).toList();

      _totalProcessCount = writablePhotos.length;
      for (var index = 0; index < writablePhotos.length; index++) {
        final photo = writablePhotos[index];
        final preview = photo.preview;
        _currentProcessCount = index + 1;
        _progress = (index + 1) / writablePhotos.length;
        _statusText = _writeToOriginal
            ? '写入 ${index + 1}/${writablePhotos.length}: ${photo.name}'
            : '导出 ${index + 1}/${writablePhotos.length}: ${photo.name}';
        notifyListeners();

        if (preview == null || !preview.matched || preview.location == null) {
          output.add(
            ProcessResult(
              photoName: photo.name,
              success: false,
              message: preview?.reason ?? '未找到匹配的位置信息',
            ),
          );
          continue;
        }

        try {
          final writeResult = await _exifService.writeGpsMetadata(
            source: photo.source,
            location: preview.location!,
            gpsTimestamp:
                preview.adjustedPhotoTime ?? preview.location!.timestamp,
            exportFolderName: _exportFolderName,
            exportFileSuffix: _exportFileSuffix,
            writeToOriginal: _writeToOriginal,
          );
          output.add(
            ProcessResult(
              photoName: photo.name,
              success: true,
              message: _buildWriteSuccessMessage(writeResult),
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
      _setMessage(_writeToOriginal ? '批量写入完成。' : '批量导出完成。');
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
    final match =
        RegExp(r'^([+-])?(\d{1,2}):(\d{2}):(\d{2})$').firstMatch(input.trim());
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

  Future<List<_PickedPhotoInput>> _pickPhotoSources() async {
    if (_writeToOriginal) {
      final picked = await _exifService.pickWritablePhotos();
      return picked
          .map(
            (item) => _PickedPhotoInput(
              name: item.name,
              readSource: item.source,
              writeSource: item.source,
              cachePath: null,
            ),
          )
          .toList(growable: false);
    }

    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'JPG', 'JPEG'],
    );
    if (result == null) {
      return const [];
    }

    return result.files
        .map(
          (picked) => _PickedPhotoInput(
            name: picked.name,
            readSource: (picked.path != null && picked.path!.isNotEmpty)
                ? picked.path
                : picked.identifier,
            writeSource:
                (picked.identifier != null && picked.identifier!.isNotEmpty)
                    ? picked.identifier
                    : picked.path,
            cachePath: picked.path,
          ),
        )
        .toList(growable: false);
  }

  String _buildWriteSuccessMessage(ExifWriteResult result) {
    if (result.wroteToOriginal) {
      return result.target == null || result.target!.isEmpty
          ? '已更新原图'
          : '已更新原图: ${result.target}';
    }
    return result.target == null || result.target!.isEmpty
        ? '无法修改原图，已另存为副本'
        : '无法修改原图，已另存为副本: ${result.target}';
  }

  String _sanitizeExportFolderName(String value) {
    final normalized = value.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .map((segment) => segment.trim().replaceAll(RegExp(r'[:*?"<>|]'), '_'))
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return segments.join('/');
  }

  String _sanitizeExportFileSuffix(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.startsWith('_') ? trimmed : '_$trimmed';
  }

  Future<void> _runBusy(String status, Future<void> Function() action) async {
    _isBusy = true;
    _progress = 0;
    _currentProcessCount = 0;
    _totalProcessCount = 0;
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
      _currentProcessCount = 0;
      _totalProcessCount = 0;
      notifyListeners();
    }
  }

  void _setMessage(String message) {
    _pendingMessage = message;
  }

  bool _canWritePhoto(SelectedPhoto photo) {
    if (!photo.canWrite) {
      return false;
    }
    return _overwriteExistingGps || !photo.hasGps;
  }

  Future<int> clearTemporaryCache() async {
    final removed = await _clearStalePickerCache();
    _pendingMessage = removed > 0 ? '已清理 $removed 个缓存项。' : '没有可清理的缓存。';
    notifyListeners();
    return removed;
  }

  Future<int> _clearStalePickerCache() async {
    final tempDir = _temporaryDirectoryPath;
    if (tempDir == null || tempDir.isEmpty) {
      return 0;
    }

    final retainedPaths = _activeManagedTempPaths();
    var removedCount = 0;

    try {
      final directory = Directory(tempDir);
      if (!await directory.exists()) {
        return 0;
      }

      await for (final entity in directory.list(followLinks: false)) {
        final normalizedPath = p.normalize(entity.path);
        if (retainedPaths.contains(normalizedPath)) {
          continue;
        }

        final name = p.basename(normalizedPath).toLowerCase();
        if (!name.contains('file_picker')) {
          continue;
        }

        if (entity is Directory) {
          await entity.delete(recursive: true);
        } else {
          await entity.delete();
        }
        removedCount++;
      }
    } catch (_) {
      // 历史缓存清理失败不影响主流程。
    }

    return removedCount;
  }

  Future<void> _cleanupSelectedPhotoCaches(List<SelectedPhoto> photos) async {
    for (final photo in photos) {
      final cachePath = photo.cachePath;
      if (cachePath == null || cachePath.isEmpty) {
        continue;
      }
      await _deleteManagedTempFile(cachePath);
    }
  }

  Future<void> _deleteManagedTempFile(String path) async {
    if (!_isManagedTempPath(path)) {
      return;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 临时文件删除失败不影响主流程。
    }
  }

  bool _isManagedTempPath(String path) {
    final tempDir = _temporaryDirectoryPath;
    if (tempDir == null || path.isEmpty) {
      return false;
    }

    final normalizedPath = p.normalize(path);
    final normalizedTempDir = p.normalize(tempDir);
    return p.equals(normalizedPath, normalizedTempDir) ||
        p.isWithin(normalizedTempDir, normalizedPath);
  }

  bool _shouldRetainCachePath({
    required String? source,
    required String cachePath,
  }) {
    return source == cachePath && _isManagedTempPath(cachePath);
  }

  Set<String> _activeManagedTempPaths() {
    return _photos
        .map((photo) => photo.cachePath)
        .whereType<String>()
        .where(_isManagedTempPath)
        .map(p.normalize)
        .toSet();
  }
}

class _PickedPhotoInput {
  const _PickedPhotoInput({
    required this.name,
    required this.readSource,
    required this.writeSource,
    required this.cachePath,
  });

  final String name;
  final String? readSource;
  final String? writeSource;
  final String? cachePath;
}
