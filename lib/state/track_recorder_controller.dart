import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recorded_track_point.dart';
import '../models/recording_draft.dart';
import '../models/recorded_track_session.dart';
import '../models/track_recording_state.dart';
import '../repositories/track_history_repository.dart';
import '../services/gpx_export_service.dart';
import '../services/location_channel_service.dart';
import '../services/track_statistics_service.dart';
import '../services/track_file_service.dart';

class TrackRecorderController extends ChangeNotifier {
  static const _recordIntervalSecondsKey = 'track.record_interval_seconds';
  static const _initialLocationPromptedKey = 'track.initial_location_prompted';

  TrackRecorderController({
    TrackHistoryRepository? repository,
    LocationChannelService? locationService,
    GpxExportService? gpxExportService,
    TrackStatisticsService? trackStatisticsService,
    TrackFileService? trackFileService,
  })  : _repository = repository ?? TrackHistoryRepository(),
        _locationService = locationService ?? LocationChannelService(),
        _gpxExportService = gpxExportService ?? GpxExportService(),
        _trackStatisticsService = trackStatisticsService ?? const TrackStatisticsService(),
        _trackFileService = trackFileService ?? TrackFileService();

  final TrackHistoryRepository _repository;
  final LocationChannelService _locationService;
  final GpxExportService _gpxExportService;
  final TrackStatisticsService _trackStatisticsService;
  final TrackFileService _trackFileService;

  List<RecordedTrackSession> _history = const [];
  TrackRecordingState _recordingState = TrackRecordingState.idle;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  int _pointCount = 0;
  bool _isLoaded = false;
  bool _locationPermissionGranted = false;
  bool _backgroundPermissionGranted = false;
  bool _locationEnabled = false;
  double? _lastLatitude;
  double? _lastLongitude;
  double? _lastAccuracy;
  DateTime? _lastTimestamp;
  StreamSubscription<RecorderStatusSnapshot>? _statusSubscription;
  String? _pendingMessage;
  String? _currentSessionId;
  final List<RecordedTrackPoint> _currentPoints = [];
  DateTime? _lastRecordedPointTimestamp;
  bool _hasRecoverableSession = false;
  DateTime _lastSnapshotReceivedAt = DateTime.now();
  SharedPreferences? _preferences;
  Future<void>? _loadFuture;

  List<RecordedTrackSession> get history => _history;
  List<RecordedTrackPoint> get currentPoints => List.unmodifiable(_currentPoints);
  TrackRecordingState get recordingState => _recordingState;
  DateTime? get startedAt => _startedAt;
  Duration get elapsed => _elapsed;
  int get pointCount => _pointCount;
  bool get isLoaded => _isLoaded;
  bool get locationPermissionGranted => _locationPermissionGranted;
  bool get backgroundPermissionGranted => _backgroundPermissionGranted;
  bool get locationEnabled => _locationEnabled;
  double? get lastLatitude => _lastLatitude;
  double? get lastLongitude => _lastLongitude;
  double? get lastAccuracy => _lastAccuracy;
  DateTime? get lastTimestamp => _lastTimestamp;
  bool get hasRecoverableSession => _hasRecoverableSession;
  DateTime get lastSnapshotReceivedAt => _lastSnapshotReceivedAt;
  double get currentDistanceMeters => _currentStatistics.distanceMeters;
  double get currentAverageSpeedMps => _currentStatistics.averageSpeedMps;
  double get currentAverageSampleIntervalSeconds =>
      _currentStatistics.averageSampleIntervalSeconds;
  double? get currentAverageAccuracyMeters =>
      _currentStatistics.averageAccuracyMeters;
  String get currentSamplingQualityLabel =>
      _currentStatistics.samplingQualityLabel;

  TrackStatistics get _currentStatistics => _trackStatisticsService.calculate(
        points: _currentPoints,
        duration: _elapsed,
      );

  String? takeMessage() {
    final value = _pendingMessage;
    _pendingMessage = null;
    return value;
  }

  Future<void> load() async {
    if (_loadFuture != null) {
      return _loadFuture!;
    }

    final future = _performLoad();
    _loadFuture = future;
    return future;
  }

  Future<void> _performLoad() async {
    if (_isLoaded) {
      return;
    }
    try {
      _history = await _repository.loadSessions();
      _statusSubscription = _locationService.statusStream().listen(_applySnapshot);
      final status = await _locationService.getStatus();
      _applySnapshot(status);
      await _hydrateNativePoints(status);
      await _restoreDraftIfNeeded();
    } catch (e) {
      debugPrint('Failed to initialize track recorder: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> requestForegroundPermission({bool showMessages = true}) async {
    try {
      final status = await _locationService.requestForegroundPermission();
      _applySnapshot(status);
      if (showMessages && !_locationPermissionGranted) {
        _pendingMessage = '定位权限仍未授予。';
      }
      notifyListeners();
    } catch (error) {
      if (showMessages) {
        _pendingMessage = '请求定位权限失败：$error';
      }
      notifyListeners();
    }
  }

  Future<void> requestBackgroundPermission({bool showMessages = true}) async {
    try {
      final status = await _locationService.requestBackgroundPermission();
      _applySnapshot(status);
      if (showMessages && !_backgroundPermissionGranted) {
        _pendingMessage = '后台定位尚未开启，切到后台后可能中断记录。';
      }
      notifyListeners();
    } catch (error) {
      if (showMessages) {
        _pendingMessage = '请求后台定位失败：$error';
      }
      notifyListeners();
    }
  }

  Future<void> maybePromptInitialLocationPermission() async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    if (preferences.getBool(_initialLocationPromptedKey) ?? false) {
      return;
    }
    await preferences.setBool(_initialLocationPromptedKey, true);
    await requestForegroundPermission(showMessages: false);
  }

  Future<void> refreshStatus() async {
    try {
      final status = await _locationService.refreshStatus();
      _applySnapshot(status);
      notifyListeners();
    } catch (error) {
      _pendingMessage = '刷新状态失败：$error';
      notifyListeners();
    }
  }

  int _recordIntervalSeconds = 5;

  int get recordIntervalSeconds => _recordIntervalSeconds;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _recordIntervalSeconds =
        (_preferences?.getInt(_recordIntervalSecondsKey) ?? _recordIntervalSeconds)
            .clamp(1, 60);
    notifyListeners();
  }

  void updateRecordInterval(int seconds) {
    if (_recordIntervalSeconds == seconds) {
      return;
    }
    _recordIntervalSeconds = seconds;
    unawaited(_preferences?.setInt(_recordIntervalSecondsKey, seconds));
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (!_locationPermissionGranted) {
      await requestForegroundPermission();
    }
    if (!_locationPermissionGranted) {
      _pendingMessage = '未获得定位权限，无法开始记录。';
      notifyListeners();
      return;
    }
    if (!_backgroundPermissionGranted) {
      await requestBackgroundPermission();
    }
    if (!_backgroundPermissionGranted) {
      _pendingMessage = '后台定位未开启，请先在系统权限页中允许后台定位。';
      notifyListeners();
      return;
    }
    if (!_locationEnabled) {
      _pendingMessage = '定位服务未开启，请先打开系统定位。';
      notifyListeners();
      return;
    }
    try {
      final status = await _locationService.startRecording(_recordIntervalSeconds * 1000);
      _currentSessionId = status.sessionId ?? status.startedAt?.microsecondsSinceEpoch.toString();
      _currentPoints.clear();
      _lastRecordedPointTimestamp = null;
      _hasRecoverableSession = false;
      _applySnapshot(status);
      await _persistDraft();
      _pendingMessage = '已开始后台轨迹记录';
      notifyListeners();
    } catch (error) {
      _pendingMessage = '开始记录失败：$error';
      notifyListeners();
    }
  }

  Future<void> pauseRecording() async {
    try {
      final status = await _locationService.pauseRecording();
      _applySnapshot(status);
      await _persistDraft();
      notifyListeners();
    } catch (error) {
      _pendingMessage = '暂停记录失败：$error';
      notifyListeners();
    }
  }

  Future<void> resumeRecording() async {
    try {
      final status = await _locationService.resumeRecording();
      _applySnapshot(status);
      await _persistDraft();
      notifyListeners();
    } catch (error) {
      _pendingMessage = '继续记录失败：$error';
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    try {
      final stopped = await _locationService.stopRecording();
      if (stopped.startedAt != null) {
        final startedAt = stopped.startedAt!;
        final sessionId = stopped.sessionId ?? _currentSessionId ?? startedAt.microsecondsSinceEpoch.toString();
        final points = stopped.points.isEmpty
            ? List<RecordedTrackPoint>.unmodifiable(_currentPoints)
            : List<RecordedTrackPoint>.unmodifiable(stopped.points);
        final stats = _trackStatisticsService.calculate(
          points: points,
          duration: stopped.elapsed,
        );
        final session = RecordedTrackSession(
          id: sessionId,
          title: _formatDateTime(startedAt),
          startedAt: startedAt,
          endedAt: stopped.endedAt,
          durationSeconds: stopped.elapsed.inSeconds,
          pointCount: points.isEmpty ? stopped.pointCount : points.length,
          stateLabel: '已保存',
          distanceMeters: stats.distanceMeters,
          averageSpeedMps: stats.averageSpeedMps,
          averageSampleIntervalSeconds: stats.averageSampleIntervalSeconds,
          averageAccuracyMeters: stats.averageAccuracyMeters,
          samplingQualityLabel: stats.samplingQualityLabel,
        );
        _history = [session, ..._history.where((item) => item.id != session.id)];
        await _repository.saveSessions(_history);
        await _repository.savePoints(session.id, points);
        await _repository.clearDraft();
        _pendingMessage = '轨迹已保存到 app 内';
      }
      _currentSessionId = null;
      _currentPoints.clear();
      _lastRecordedPointTimestamp = null;
      _hasRecoverableSession = false;
      final status = await _locationService.getStatus();
      _applySnapshot(status);
      notifyListeners();
    } catch (error) {
      _pendingMessage = '停止记录失败：$error';
      notifyListeners();
    }
  }

  Future<void> renameSession(String id, String title) async {
    final index = _history.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    try {
      _history = List.of(_history);
      final existing = _history[index];
      await _trackFileService.deleteExportedFile(existing.exportedGpxPath);
      _history[index] = existing.copyWith(title: title, clearExportedPath: true);
      await _repository.saveSessions(_history);
      _pendingMessage = '轨迹名称已更新';
      notifyListeners();
    } catch (error) {
      _pendingMessage = '重命名失败：$error';
      notifyListeners();
    }
  }

  Future<void> deleteSession(String id) async {
    RecordedTrackSession? session;
    for (final entry in _history) {
      if (entry.id == id) {
        session = entry;
        break;
      }
    }
    try {
      _history = _history.where((item) => item.id != id).toList(growable: false);
      await _repository.saveSessions(_history);
      await _repository.deletePoints(id);
      await _trackFileService.deleteExportedFile(session?.exportedGpxPath);
      _pendingMessage = '轨迹已删除';
      notifyListeners();
    } catch (error) {
      _pendingMessage = '删除轨迹失败：$error';
      notifyListeners();
    }
  }

  Future<List<RecordedTrackPoint>> loadSessionPoints(String sessionId) {
    return _repository.loadPoints(sessionId);
  }

  Future<String?> exportSession(String sessionId) async {
    RecordedTrackSession? session;
    for (final entry in _history) {
      if (entry.id == sessionId) {
        session = entry;
        break;
      }
    }
    if (session == null) {
      return null;
    }
    try {
      final points = await _repository.loadPoints(sessionId);
      if (points.isEmpty) {
        _pendingMessage = '这条轨迹还没有可导出的定位点。';
        notifyListeners();
        return null;
      }
      final gpx = _gpxExportService.buildGpx(name: session.title, points: points);
      final file = await _trackFileService.writeExportedGpx(session: session, gpxContent: gpx);
      final updated = session.copyWith(exportedGpxPath: file.path, stateLabel: '已导出');
      _history = _history.map((item) => item.id == sessionId ? updated : item).toList(growable: false);
      await _repository.saveSessions(_history);
      _pendingMessage = '已导出 GPX 到 ${file.path}';
      notifyListeners();
      return file.path;
    } catch (error) {
      _pendingMessage = '导出 GPX 失败：$error';
      notifyListeners();
      return null;
    }
  }

  Future<void> shareSession(String sessionId) async {
    try {
      final path = await exportSession(sessionId);
      if (path == null) {
        return;
      }
      await Share.shareXFiles([XFile(path)]);
      _pendingMessage = '已调用系统分享';
      notifyListeners();
    } catch (error) {
      _pendingMessage = '分享失败：$error';
      notifyListeners();
    }
  }

  void markUsedForGeotag(RecordedTrackSession session) {
    _pendingMessage = '已将“${session.title}”送到写入页。';
    notifyListeners();
  }

  Future<void> dismissRecoveredSession() async {
    _currentSessionId = null;
    _currentPoints.clear();
    _lastRecordedPointTimestamp = null;
    _hasRecoverableSession = false;
    _startedAt = null;
    _elapsed = Duration.zero;
    _pointCount = 0;
    _recordingState = TrackRecordingState.idle;
    await _repository.clearDraft();
    notifyListeners();
  }

  void _applySnapshot(RecorderStatusSnapshot snapshot) {
    _lastSnapshotReceivedAt = DateTime.now();
    _recordingState = snapshot.state;
    _startedAt = snapshot.startedAt;
    _elapsed = snapshot.elapsed;
    _pointCount = snapshot.pointCount;
    _locationPermissionGranted = snapshot.locationPermissionGranted;
    _backgroundPermissionGranted = snapshot.backgroundPermissionGranted;
    _locationEnabled = snapshot.locationEnabled;
    _lastLatitude = snapshot.lastLatitude;
    _lastLongitude = snapshot.lastLongitude;
    _lastAccuracy = snapshot.lastAccuracy;
    _lastTimestamp = snapshot.lastTimestamp;

    if (_recordingState != TrackRecordingState.idle &&
        _currentSessionId == null &&
        (snapshot.sessionId != null || snapshot.startedAt != null)) {
      _currentSessionId =
          snapshot.sessionId ?? snapshot.startedAt!.microsecondsSinceEpoch.toString();
    }

    if (_recordingState == TrackRecordingState.recording &&
        _currentSessionId != null &&
        snapshot.lastLatitude != null &&
        snapshot.lastLongitude != null &&
        snapshot.lastTimestamp != null &&
        snapshot.lastTimestamp != _lastRecordedPointTimestamp) {
      _currentPoints.add(
        RecordedTrackPoint(
          sessionId: _currentSessionId!,
          latitude: snapshot.lastLatitude!,
          longitude: snapshot.lastLongitude!,
          altitude: snapshot.lastAltitude,
          accuracy: snapshot.lastAccuracy,
          speed: snapshot.lastSpeed,
          timestamp: snapshot.lastTimestamp!,
        ),
      );
      _lastRecordedPointTimestamp = snapshot.lastTimestamp;
      unawaited(_persistDraft());
    }
    notifyListeners();
  }

  Future<void> _restoreDraftIfNeeded() async {
    final draft = await _repository.loadDraft();
    if (draft == null) {
      return;
    }

    if (_recordingState != TrackRecordingState.idle && _currentPoints.isNotEmpty) {
      return;
    }

    final stats = _trackStatisticsService.calculate(
      points: draft.points,
      duration: Duration(seconds: draft.elapsedSeconds),
    );

    if (_recordingState == TrackRecordingState.idle) {
      final recovered = RecordedTrackSession(
        id: draft.sessionId,
        title: '${_formatDateTime(draft.startedAt)} 恢复',
        startedAt: draft.startedAt,
        endedAt: DateTime.now(),
        durationSeconds: draft.elapsedSeconds,
        pointCount: draft.points.length,
        stateLabel: '中断恢复',
        distanceMeters: stats.distanceMeters,
        averageSpeedMps: stats.averageSpeedMps,
        averageSampleIntervalSeconds: stats.averageSampleIntervalSeconds,
        averageAccuracyMeters: stats.averageAccuracyMeters,
        samplingQualityLabel: stats.samplingQualityLabel,
      );
      _history = [recovered, ..._history.where((item) => item.id != recovered.id)];
      await _repository.saveSessions(_history);
      await _repository.savePoints(recovered.id, draft.points);
      await _repository.clearDraft();
      _pendingMessage = '检测到未正常结束的记录，已恢复到历史列表。';
      return;
    }

    _currentSessionId = draft.sessionId;
    _currentPoints
      ..clear()
      ..addAll(draft.points);
    _lastRecordedPointTimestamp = draft.points.isEmpty ? null : draft.points.last.timestamp;
    _startedAt = draft.startedAt;
    _elapsed = Duration(seconds: draft.elapsedSeconds);
    _pointCount = draft.pointCount;
    _hasRecoverableSession = true;
    _pendingMessage = '已恢复未完成的记录会话。';
  }

  Future<void> _hydrateNativePoints(RecorderStatusSnapshot status) async {
    if (status.state == TrackRecordingState.idle) {
      return;
    }

    final sessionId = status.sessionId ?? status.startedAt?.microsecondsSinceEpoch.toString();
    if (sessionId == null) {
      return;
    }

    final points = await _locationService.getRecordedPoints(sessionId);
    if (points.isEmpty) {
      return;
    }

    _currentSessionId = sessionId;
    _currentPoints
      ..clear()
      ..addAll(points);
    _lastRecordedPointTimestamp = points.last.timestamp;
  }

  Future<void> _persistDraft() async {
    if (_currentSessionId == null || _startedAt == null) {
      return;
    }
    if (_recordingState == TrackRecordingState.idle) {
      return;
    }
    await _repository.saveDraft(
      RecordingDraft(
        sessionId: _currentSessionId!,
        startedAt: _startedAt!,
        elapsedSeconds: _elapsed.inSeconds,
        pointCount: _pointCount,
        points: List<RecordedTrackPoint>.unmodifiable(_currentPoints),
      ),
    );
  }

  String _formatDateTime(DateTime time) {
    final year = time.year.toString().padLeft(4, '0');
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> openAppPermissionSettings() {
    return _locationService.openAppSettings();
  }

  Future<void> openLocationSettings() {
    return _locationService.openLocationSettings();
  }
}
