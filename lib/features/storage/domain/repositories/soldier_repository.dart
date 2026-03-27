import '../../../../core/utils/result.dart';
import '../entities/shot_record.dart';
import '../entities/soldier.dart';

/// Query options for [SoldierRepository.getShotHistory].
class ShotHistoryQuery {
  const ShotHistoryQuery({
    required this.soldierId,
    this.limit,
    this.offset,
    this.from,
    this.to,
    this.pattern,
    this.errorType,
  });

  final String soldierId;

  /// Maximum rows to return.  null = no limit.
  final int? limit;

  /// Rows to skip (for pagination).  null = 0.
  final int? offset;

  /// Inclusive lower bound (UTC).
  final DateTime? from;

  /// Inclusive upper bound (UTC).
  final DateTime? to;

  /// Filter by exact pattern string, e.g. "horizontal".  null = all patterns.
  final String? pattern;

  /// Filter by error type string, e.g. "jerk".  null = all error types.
  final String? errorType;
}

/// Abstract contract for soldier + shot-record persistence.
///
/// All methods return [Result<T>] — callers never catch raw exceptions.
abstract interface class SoldierRepository {
  // ── Soldiers ───────────────────────────────────────────────────────────────

  /// Inserts or replaces a [Soldier] row (upsert via CONFLICT REPLACE).
  Future<Result<void>> upsertSoldier(Soldier soldier);

  Future<Result<Soldier?>> getSoldierById(String id);

  Future<Result<List<Soldier>>> getAllSoldiers();

  /// Deletes the soldier and cascades to all their [ShotRecord]s.
  Future<Result<void>> deleteSoldier(String id);

  // ── Shot records ───────────────────────────────────────────────────────────

  /// Inserts a single [ShotRecord] and returns its new auto-assigned [id].
  Future<Result<int>> insertShotRecord(ShotRecord record);

  /// Inserts [records] in a single SQLite batch (one transaction).
  ///
  /// Returns the list of auto-assigned ids in the same order as [records].
  /// Prefer this over calling [insertShotRecord] in a loop.
  Future<Result<List<int>>> batchInsertShotRecords(List<ShotRecord> records);

  /// Returns shot history for a soldier, filtered and paginated by [query].
  ///
  /// Results are ordered by [ShotRecord.createdAt] descending (newest first).
  Future<Result<List<ShotRecord>>> getShotHistory(ShotHistoryQuery query);

  /// Total number of shots stored for a soldier.
  Future<Result<int>> countShots(String soldierId);

  /// Removes all shot records for [soldierId] without deleting the soldier row.
  Future<Result<void>> clearHistory(String soldierId);
}
