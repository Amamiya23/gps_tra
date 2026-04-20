import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/recorded_track_point.dart';
import '../models/recorded_track_session.dart';
import '../models/recording_draft.dart';

class TrackHistoryRepository {
  Database? _database;

  Future<List<RecordedTrackSession>> loadSessions() async {
    final database = await _db;
    final rows = await database.query(
      'track_sessions',
      orderBy: 'started_at DESC',
    );
    return rows.map(_sessionFromRow).toList(growable: false);
  }

  Future<void> saveSessions(List<RecordedTrackSession> sessions) async {
    final database = await _db;
    await database.transaction((txn) async {
      await txn.delete('track_sessions');
      for (final session in sessions) {
        await txn.insert(
          'track_sessions',
          _sessionToRow(session),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<RecordedTrackPoint>> loadPoints(String sessionId) async {
    final database = await _db;
    final rows = await database.query(
      'track_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_pointFromRow).toList(growable: false);
  }

  Future<void> savePoints(String sessionId, List<RecordedTrackPoint> points) async {
    final database = await _db;
    await database.transaction((txn) async {
      await txn.delete(
        'track_points',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      for (final point in points) {
        await txn.insert('track_points', _pointToRow(point));
      }
    });
  }

  Future<void> deletePoints(String sessionId) async {
    final database = await _db;
    await database.delete(
      'track_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> saveSession(RecordedTrackSession session) async {
    final database = await _db;
    await database.insert(
      'track_sessions',
      _sessionToRow(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RecordingDraft?> loadDraft() async {
    final database = await _db;
    final rows = await database.query('recording_draft', limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    final rawPoints = row['points_json'] as String?;
    final points = rawPoints == null || rawPoints.isEmpty
        ? const <RecordedTrackPoint>[]
        : (jsonDecode(rawPoints) as List<dynamic>)
            .map((item) => RecordedTrackPoint.fromJson(item as Map<String, dynamic>))
            .toList(growable: false);

    return RecordingDraft(
      sessionId: row['session_id'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
      elapsedSeconds: row['elapsed_seconds'] as int,
      pointCount: row['point_count'] as int,
      points: points,
    );
  }

  Future<void> saveDraft(RecordingDraft draft) async {
    final database = await _db;
    await database.delete('recording_draft');
    await database.insert('recording_draft', {
      'id': 1,
      'session_id': draft.sessionId,
      'started_at': draft.startedAt.millisecondsSinceEpoch,
      'elapsed_seconds': draft.elapsedSeconds,
      'point_count': draft.pointCount,
      'points_json': jsonEncode(
        draft.points.map((item) => item.toJson()).toList(growable: false),
      ),
    });
  }

  Future<void> clearDraft() async {
    final database = await _db;
    await database.delete('recording_draft');
  }

  Future<Database> get _db async {
    _database ??= await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'track_history.db');
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
    await _migrateFromJsonIfNeeded(database, directory.path);
    return database;
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS track_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        duration_seconds INTEGER NOT NULL,
        point_count INTEGER NOT NULL,
        state_label TEXT NOT NULL,
        distance_meters REAL NOT NULL DEFAULT 0,
        average_speed_mps REAL NOT NULL DEFAULT 0,
        average_sample_interval_seconds REAL NOT NULL DEFAULT 0,
        average_accuracy_meters REAL,
        sampling_quality_label TEXT NOT NULL DEFAULT '未知',
        exported_gpx_path TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS track_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        accuracy REAL,
        speed REAL,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recording_draft (
        id INTEGER PRIMARY KEY,
        session_id TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        elapsed_seconds INTEGER NOT NULL,
        point_count INTEGER NOT NULL,
        points_json TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateFromJsonIfNeeded(Database database, String rootPath) async {
    final existing = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM track_sessions'),
    );
    final hasDraft = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM recording_draft'),
    );
    if ((existing ?? 0) > 0 || (hasDraft ?? 0) > 0) {
      return;
    }

    final sessionsFile = File(p.join(rootPath, 'track_history.json'));
    if (await sessionsFile.exists()) {
      final raw = await sessionsFile.readAsString();
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          final session = RecordedTrackSession.fromJson(item as Map<String, dynamic>);
          await database.insert(
            'track_sessions',
            _sessionToRow(session),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          final pointsFile = File(p.join(rootPath, 'track_points', '${session.id}.json'));
          if (await pointsFile.exists()) {
            final pointRaw = await pointsFile.readAsString();
            if (pointRaw.trim().isNotEmpty) {
              final pointDecoded = jsonDecode(pointRaw) as List<dynamic>;
              for (final pointItem in pointDecoded) {
                final point = RecordedTrackPoint.fromJson(pointItem as Map<String, dynamic>);
                await database.insert('track_points', _pointToRow(point));
              }
            }
          }
        }
      }
    }

    final draftFile = File(p.join(rootPath, 'track_recording_draft.json'));
    if (await draftFile.exists()) {
      final raw = await draftFile.readAsString();
      if (raw.trim().isNotEmpty) {
        final draft = RecordingDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        await database.insert('recording_draft', {
          'id': 1,
          'session_id': draft.sessionId,
          'started_at': draft.startedAt.millisecondsSinceEpoch,
          'elapsed_seconds': draft.elapsedSeconds,
          'point_count': draft.pointCount,
          'points_json': jsonEncode(
            draft.points.map((item) => item.toJson()).toList(growable: false),
          ),
        });
      }
    }
  }

  Map<String, Object?> _sessionToRow(RecordedTrackSession session) {
    return {
      'id': session.id,
      'title': session.title,
      'started_at': session.startedAt.millisecondsSinceEpoch,
      'ended_at': session.endedAt?.millisecondsSinceEpoch,
      'duration_seconds': session.durationSeconds,
      'point_count': session.pointCount,
      'state_label': session.stateLabel,
      'distance_meters': session.distanceMeters,
      'average_speed_mps': session.averageSpeedMps,
      'average_sample_interval_seconds': session.averageSampleIntervalSeconds,
      'average_accuracy_meters': session.averageAccuracyMeters,
      'sampling_quality_label': session.samplingQualityLabel,
      'exported_gpx_path': session.exportedGpxPath,
    };
  }

  RecordedTrackSession _sessionFromRow(Map<String, Object?> row) {
    return RecordedTrackSession(
      id: row['id'] as String,
      title: row['title'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
      endedAt: row['ended_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
      durationSeconds: row['duration_seconds'] as int,
      pointCount: row['point_count'] as int,
      stateLabel: row['state_label'] as String,
      distanceMeters: (row['distance_meters'] as num?)?.toDouble() ?? 0,
      averageSpeedMps: (row['average_speed_mps'] as num?)?.toDouble() ?? 0,
      averageSampleIntervalSeconds:
          (row['average_sample_interval_seconds'] as num?)?.toDouble() ?? 0,
      averageAccuracyMeters: (row['average_accuracy_meters'] as num?)?.toDouble(),
      samplingQualityLabel: row['sampling_quality_label'] as String? ?? '未知',
      exportedGpxPath: row['exported_gpx_path'] as String?,
    );
  }

  Map<String, Object?> _pointToRow(RecordedTrackPoint point) {
    return {
      'session_id': point.sessionId,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'altitude': point.altitude,
      'accuracy': point.accuracy,
      'speed': point.speed,
      'timestamp': point.timestamp.millisecondsSinceEpoch,
    };
  }

  RecordedTrackPoint _pointFromRow(Map<String, Object?> row) {
    return RecordedTrackPoint(
      sessionId: row['session_id'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      altitude: (row['altitude'] as num?)?.toDouble(),
      accuracy: (row['accuracy'] as num?)?.toDouble(),
      speed: (row['speed'] as num?)?.toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    );
  }
}
