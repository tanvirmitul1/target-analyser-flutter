/// SQLite database schema constants — single source of truth for every table
/// name, column name, DDL statement, and index.
///
/// Version history:
///   v1 — sessions, shots (image-capture pipeline)
///   v2 — soldiers, soldier_shots (analysis / pattern storage)
abstract final class DbConstants {
  DbConstants._();

  static const String dbName = 'target_analyser.db';

  /// Bump this when adding a new migration.  [DatabaseService] reads it.
  static const int dbVersion = 2;

  // ════════════════════════════════════════════════════════════════════════════
  // v1 — Sessions
  // ════════════════════════════════════════════════════════════════════════════

  static const String tableSession    = 'sessions';
  static const String colSessionId        = 'id';
  static const String colSessionName      = 'name';
  static const String colSessionDate      = 'date';
  static const String colSessionNotes     = 'notes';
  static const String colSessionCreatedAt = 'created_at';

  // ════════════════════════════════════════════════════════════════════════════
  // v1 — Shots (image-capture, belongs to a session)
  // ════════════════════════════════════════════════════════════════════════════

  static const String tableShot             = 'shots';
  static const String colShotId             = 'id';
  static const String colShotSessionId      = 'session_id';
  static const String colShotImagePath      = 'image_path';
  static const String colShotProcessedPath  = 'processed_image_path';
  static const String colShotScore          = 'score';
  static const String colShotRing           = 'ring';
  static const String colShotX             = 'x';
  static const String colShotY             = 'y';
  static const String colShotTimestamp      = 'timestamp';

  // ════════════════════════════════════════════════════════════════════════════
  // v2 — Soldiers
  // ════════════════════════════════════════════════════════════════════════════

  static const String tableSoldier    = 'soldiers';
  static const String colSoldierId    = 'id';

  // ════════════════════════════════════════════════════════════════════════════
  // v2 — Soldier shots (analysis results, belongs to a soldier)
  // ════════════════════════════════════════════════════════════════════════════

  /// Separate from [tableShot]: this table stores computed analysis data
  /// (pattern, error, angle …) keyed by soldier rather than session.
  static const String tableSoldierShot            = 'soldier_shots';
  static const String colSoldierShotId            = 'id';          // INTEGER AUTOINCREMENT
  static const String colSoldierShotSoldierId     = 'soldier_id';
  static const String colSoldierShotX             = 'x';
  static const String colSoldierShotY             = 'y';
  static const String colSoldierShotDistance      = 'distance';
  static const String colSoldierShotAngle         = 'angle';
  static const String colSoldierShotPattern       = 'pattern';
  static const String colSoldierShotErrorType     = 'error_type';  // nullable
  /// Unix epoch in milliseconds — stored as INTEGER for efficient range queries.
  static const String colSoldierShotCreatedAt     = 'created_at';

  // ── Indexes (v2) ──────────────────────────────────────────────────────────

  /// Primary query path: all shots for one soldier.
  static const String idxSoldierShotSoldierId =
      'idx_soldier_shots_soldier_id';

  /// Secondary: date-range queries and ORDER BY created_at.
  static const String idxSoldierShotCreatedAt =
      'idx_soldier_shots_created_at';

  // ════════════════════════════════════════════════════════════════════════════
  // DDL
  // ════════════════════════════════════════════════════════════════════════════

  // ── v1 ────────────────────────────────────────────────────────────────────

  static const String createSessionTable = '''
    CREATE TABLE $tableSession (
      $colSessionId          TEXT PRIMARY KEY NOT NULL,
      $colSessionName        TEXT NOT NULL,
      $colSessionDate        TEXT NOT NULL,
      $colSessionNotes       TEXT,
      $colSessionCreatedAt   TEXT NOT NULL
    )
  ''';

  static const String createShotTable = '''
    CREATE TABLE $tableShot (
      $colShotId             TEXT    PRIMARY KEY NOT NULL,
      $colShotSessionId      TEXT    NOT NULL,
      $colShotImagePath      TEXT    NOT NULL,
      $colShotProcessedPath  TEXT,
      $colShotScore          REAL    NOT NULL DEFAULT 0,
      $colShotRing           INTEGER NOT NULL DEFAULT 0,
      $colShotX              REAL    NOT NULL DEFAULT 0,
      $colShotY              REAL    NOT NULL DEFAULT 0,
      $colShotTimestamp      TEXT    NOT NULL,
      FOREIGN KEY ($colShotSessionId)
        REFERENCES $tableSession ($colSessionId) ON DELETE CASCADE
    )
  ''';

  // ── v2 ────────────────────────────────────────────────────────────────────

  static const String createSoldierTable = '''
    CREATE TABLE $tableSoldier (
      $colSoldierId  TEXT PRIMARY KEY NOT NULL
    )
  ''';

  static const String createSoldierShotTable = '''
    CREATE TABLE $tableSoldierShot (
      $colSoldierShotId         INTEGER PRIMARY KEY AUTOINCREMENT,
      $colSoldierShotSoldierId  TEXT    NOT NULL,
      $colSoldierShotX          REAL    NOT NULL DEFAULT 0,
      $colSoldierShotY          REAL    NOT NULL DEFAULT 0,
      $colSoldierShotDistance   REAL    NOT NULL DEFAULT 0,
      $colSoldierShotAngle      REAL    NOT NULL DEFAULT 0,
      $colSoldierShotPattern    TEXT    NOT NULL DEFAULT '',
      $colSoldierShotErrorType  TEXT,
      $colSoldierShotCreatedAt  INTEGER NOT NULL,
      FOREIGN KEY ($colSoldierShotSoldierId)
        REFERENCES $tableSoldier ($colSoldierId) ON DELETE CASCADE
    )
  ''';

  static const String createIdxSoldierShotSoldierId = '''
    CREATE INDEX $idxSoldierShotSoldierId
      ON $tableSoldierShot ($colSoldierShotSoldierId)
  ''';

  static const String createIdxSoldierShotCreatedAt = '''
    CREATE INDEX $idxSoldierShotCreatedAt
      ON $tableSoldierShot ($colSoldierShotCreatedAt)
  ''';
}
