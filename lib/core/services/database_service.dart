import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/db_constants.dart';
import '../utils/logger.dart';

/// Singleton that owns the SQLite [Database] instance.
///
/// Always call [init] once at app start (before any repository usage).
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Database get db {
    assert(_db != null, 'DatabaseService.init() must be called before use.');
    return _db!;
  }

  /// Opens (and migrates) the database.  Safe to call multiple times.
  Future<void> init() async {
    if (_db != null) return;

    AppLogger.i('Initialising database…');

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.dbName);

    _db = await openDatabase(
      path,
      version: DbConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );

    AppLogger.i('Database ready at $path');
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    AppLogger.d('Creating database schema (v$version)…');
    final batch = db.batch();
    batch.execute(DbConstants.createSessionTable);
    batch.execute(DbConstants.createShotTable);
    await batch.commit(noResult: true);
    AppLogger.d('Schema created.');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.i('Migrating database from v$oldVersion to v$newVersion…');
    // Add migration steps here as the schema evolves.
    // Example:
    // if (oldVersion < 2) { await db.execute('ALTER TABLE …'); }
  }

  /// Closes the database connection.  Useful in tests.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
