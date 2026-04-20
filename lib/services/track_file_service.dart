import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/recorded_track_session.dart';

class TrackFileService {
  Future<File> writeExportedGpx({
    required RecordedTrackSession session,
    required String gpxContent,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(directory.path, 'exports'));
    await exportDir.create(recursive: true);
    final fileName = '${session.id}_${_sanitizeFileName(session.title)}.gpx';
    final file = File(p.join(exportDir.path, fileName));
    await file.writeAsString(gpxContent);
    return file;
  }

  Future<void> deleteExportedFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      return;
    }
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(' ', '_');
  }
}
