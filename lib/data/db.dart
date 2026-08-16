import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../recsys/events.dart';

/// SQLite persistence for listening events + the local library.
/// Uses sqflite_common_ffi (no codegen, desktop-friendly).
final class HirenaDb {
  HirenaDb._(this._db);

  final Database _db;

  static Future<HirenaDb> open() async {
    sqfliteFfiInit();
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'hirena.db');
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE listening_events(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              track_id INTEGER NOT NULL,
              started_at INTEGER NOT NULL,
              duration_ms INTEGER NOT NULL,
              completion_ratio REAL NOT NULL,
              action TEXT NOT NULL,
              artist_id INTEGER,
              genre_id INTEGER,
              bpm INTEGER,
              gain REAL,
              session_id TEXT,
              position_in_session INTEGER NOT NULL DEFAULT 0,
              smart INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('CREATE INDEX idx_events_track ON listening_events(track_id)');
          await db.execute('CREATE INDEX idx_events_started ON listening_events(started_at)');
          await db.execute('''
            CREATE TABLE saved_tracks(
              track_id INTEGER PRIMARY KEY,
              track_json TEXT NOT NULL,
              saved_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    return HirenaDb._(db);
  }

  Future<void> insertEvent(ListeningEvent e) async {
    await _db.insert('listening_events', e.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ListeningEvent>> events({int limit = 20000}) async {
    final rows = await _db.query(
      'listening_events',
      orderBy: 'started_at ASC',
      limit: limit,
    );
    return rows.map(ListeningEvent.fromRow).toList();
  }

  Future<void> saveTrack(String trackJson, {required int trackId}) async {
    await _db.insert(
      'saved_tracks',
      {
        'track_id': trackId,
        'track_json': trackJson,
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> unsaveTrack(int trackId) async {
    await _db.delete('saved_tracks', where: 'track_id = ?', whereArgs: [trackId]);
  }

  Future<bool> isSaved(int trackId) async {
    final rows = await _db.query('saved_tracks',
        where: 'track_id = ?', whereArgs: [trackId], limit: 1);
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> savedTracks() async {
    final rows = await _db.query('saved_tracks', orderBy: 'saved_at DESC');
    return rows
        .map((r) => jsonDecode(r['track_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> close() => _db.close();
}
