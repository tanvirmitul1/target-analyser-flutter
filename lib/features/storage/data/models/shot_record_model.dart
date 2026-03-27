import '../../../../core/constants/db_constants.dart';
import '../../domain/entities/shot_record.dart';

/// SQLite DTO for the `soldier_shots` table.
///
/// [createdAt] is stored as a Unix-epoch millisecond INTEGER so that SQLite
/// can use the [DbConstants.idxSoldierShotCreatedAt] index for range queries
/// without any string-parsing overhead.
class ShotRecordModel {
  const ShotRecordModel({
    required this.soldierId,
    required this.x,
    required this.y,
    required this.distance,
    required this.angle,
    required this.pattern,
    required this.createdAtMs,
    this.id,
    this.errorType,
  });

  final int? id;
  final String soldierId;
  final double x;
  final double y;
  final double distance;
  final double angle;
  final String pattern;
  final String? errorType;

  /// Milliseconds since epoch (UTC).
  final int createdAtMs;

  // ── Mapping ────────────────────────────────────────────────────────────────

  factory ShotRecordModel.fromMap(Map<String, dynamic> map) => ShotRecordModel(
        id: map[DbConstants.colSoldierShotId] as int?,
        soldierId:
            map[DbConstants.colSoldierShotSoldierId] as String,
        x: (map[DbConstants.colSoldierShotX] as num).toDouble(),
        y: (map[DbConstants.colSoldierShotY] as num).toDouble(),
        distance:
            (map[DbConstants.colSoldierShotDistance] as num).toDouble(),
        angle:
            (map[DbConstants.colSoldierShotAngle] as num).toDouble(),
        pattern:
            map[DbConstants.colSoldierShotPattern] as String,
        errorType:
            map[DbConstants.colSoldierShotErrorType] as String?,
        createdAtMs:
            map[DbConstants.colSoldierShotCreatedAt] as int,
      );

  /// Column map ready for [DatabaseService.db.insert].
  ///
  /// [id] is deliberately omitted — SQLite assigns it via AUTOINCREMENT.
  Map<String, dynamic> toMap() => {
        DbConstants.colSoldierShotSoldierId: soldierId,
        DbConstants.colSoldierShotX:         x,
        DbConstants.colSoldierShotY:         y,
        DbConstants.colSoldierShotDistance:  distance,
        DbConstants.colSoldierShotAngle:     angle,
        DbConstants.colSoldierShotPattern:   pattern,
        DbConstants.colSoldierShotErrorType: errorType,
        DbConstants.colSoldierShotCreatedAt: createdAtMs,
      };

  ShotRecord toDomain() => ShotRecord(
        id:         id,
        soldierId:  soldierId,
        x:          x,
        y:          y,
        distance:   distance,
        angle:      angle,
        pattern:    pattern,
        errorType:  errorType,
        createdAt:  DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
      );

  factory ShotRecordModel.fromDomain(ShotRecord r) => ShotRecordModel(
        id:          r.id,
        soldierId:   r.soldierId,
        x:           r.x,
        y:           r.y,
        distance:    r.distance,
        angle:       r.angle,
        pattern:     r.pattern,
        errorType:   r.errorType,
        createdAtMs: r.createdAt.toUtc().millisecondsSinceEpoch,
      );
}
