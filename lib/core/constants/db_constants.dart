/// SQLite database schema constants — single source of truth.
abstract final class DbConstants {
  DbConstants._();

  static const String dbName = 'target_analyser.db';
  static const int dbVersion = 1;

  // ── Sessions table ────────────────────────────────────────────────────────
  static const String tableSession = 'sessions';
  static const String colSessionId = 'id';
  static const String colSessionName = 'name';
  static const String colSessionDate = 'date';
  static const String colSessionNotes = 'notes';
  static const String colSessionCreatedAt = 'created_at';

  // ── Shots table ───────────────────────────────────────────────────────────
  static const String tableShot = 'shots';
  static const String colShotId = 'id';
  static const String colShotSessionId = 'session_id';
  static const String colShotImagePath = 'image_path';
  static const String colShotProcessedPath = 'processed_image_path';
  static const String colShotScore = 'score';
  static const String colShotRing = 'ring';
  static const String colShotX = 'x';
  static const String colShotY = 'y';
  static const String colShotTimestamp = 'timestamp';

  // ── DDL ───────────────────────────────────────────────────────────────────
  static const String createSessionTable = '''
    CREATE TABLE $tableSession (
      $colSessionId     TEXT PRIMARY KEY,
      $colSessionName   TEXT NOT NULL,
      $colSessionDate   TEXT NOT NULL,
      $colSessionNotes  TEXT,
      $colSessionCreatedAt TEXT NOT NULL
    )
  ''';

  static const String createShotTable = '''
    CREATE TABLE $tableShot (
      $colShotId            TEXT PRIMARY KEY,
      $colShotSessionId     TEXT NOT NULL,
      $colShotImagePath     TEXT NOT NULL,
      $colShotProcessedPath TEXT,
      $colShotScore         REAL NOT NULL DEFAULT 0,
      $colShotRing          INTEGER NOT NULL DEFAULT 0,
      $colShotX             REAL NOT NULL DEFAULT 0,
      $colShotY             REAL NOT NULL DEFAULT 0,
      $colShotTimestamp     TEXT NOT NULL,
      FOREIGN KEY ($colShotSessionId) REFERENCES $tableSession ($colSessionId)
        ON DELETE CASCADE
    )
  ''';
}
