import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/db_constants.dart';
import '../utils/logger.dart';

/// Singleton that owns the single SQLite [Database] connection.
///
/// ## Usage
/// ```dart
/// await DatabaseService.instance.init();   // call once in main()
/// final db = DatabaseService.instance.db; // then use anywhere
/// ```
///
/// ## Migration strategy
/// • [_onCreate]  — called on a **fresh install**.  Creates the complete
///   schema for the current [DbConstants.dbVersion].
/// • [_onUpgrade] — called when an existing database version is lower than
///   [DbConstants.dbVersion].  Each block is guarded by `if (old < N)` so
///   migrations are **additive and idempotent** across multiple version jumps.
///
/// Never rename or drop existing columns inside a migration; add new tables
/// or columns via ALTER TABLE ADD COLUMN instead.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Database get db {
    assert(_db != null, 'DatabaseService.init() must be called before use.');
    return _db!;
  }

  // ── Public ─────────────────────────────────────────────────────────────────

  /// Opens (and migrates) the database.  Safe to call multiple times.
  Future<void> init() async {
    if (_db != null) return;

    AppLogger.i('Initialising database (target version ${DbConstants.dbVersion})…');

    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, DbConstants.dbName);

    _db = await openDatabase(
      path,
      version:     DbConstants.dbVersion,
      onConfigure: _onConfigure,
      onCreate:    _onCreate,
      onUpgrade:   _onUpgrade,
    );

    AppLogger.i('Database ready at $path');
  }

  /// Closes the connection.  Use in tests and when running migrations manually.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── Lifecycle callbacks ─────────────────────────────────────────────────────

  Future<void> _onConfigure(Database db) async {
    // Must be enabled before any other statements so FK constraints fire.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Creates the **complete** schema for a fresh install.
  ///
  /// A Batch is used so all DDL runs atomically in a single transaction.
  Future<void> _onCreate(Database db, int version) async {
    AppLogger.d('_onCreate: building schema v$version from scratch…');

    final batch = db.batch();

    // ── v1 tables ────────────────────────────────────────────────────────────
    batch.execute(DbConstants.createSessionTable);
    batch.execute(DbConstants.createShotTable);

    // ── v2 tables + indexes ───────────────────────────────────────────────────
    batch.execute(DbConstants.createSoldierTable);
    batch.execute(DbConstants.createSoldierShotTable);
    batch.execute(DbConstants.createIdxSoldierShotSoldierId);
    batch.execute(DbConstants.createIdxSoldierShotCreatedAt);

    await batch.commit(noResult: true);
    AppLogger.d('_onCreate: schema complete.');
  }

  /// Applies incremental migrations from [oldVersion] to [newVersion].
  ///
  /// Rules:
  ///   • Wrap each version step in `if (oldVersion < N)`.
  ///   • Only ADD structure (new tables, new columns via ALTER ADD COLUMN,
  ///     new indexes).  Never DROP or RENAME existing columns.
  ///   • Each migration block should be self-contained; any complex multi-step
  ///     work must be inside its own transaction via [db.transaction].
  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    AppLogger.i('_onUpgrade: v$oldVersion → v$newVersion');

    // ── v1 → v2: add soldiers + soldier_shots tables ──────────────────────────
    if (oldVersion < 2) {
      AppLogger.d('Applying migration v2…');
      await db.transaction((txn) async {
        await txn.execute(DbConstants.createSoldierTable);
        await txn.execute(DbConstants.createSoldierShotTable);
        await txn.execute(DbConstants.createIdxSoldierShotSoldierId);
        await txn.execute(DbConstants.createIdxSoldierShotCreatedAt);
      });
      AppLogger.d('Migration v2 complete.');
    }

    // ── v2 → v3: placeholder (add your next migration here) ───────────────────
    // if (oldVersion < 3) { ... }

    AppLogger.i('_onUpgrade: all migrations applied.');
  }
}
