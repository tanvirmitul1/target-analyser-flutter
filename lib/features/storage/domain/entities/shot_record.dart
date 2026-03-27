import 'package:equatable/equatable.dart';

/// Domain entity for one persisted shot-analysis record.
///
/// Stored in the `soldier_shots` table (v2 schema).
/// [id] is null before the record is inserted and assigned by SQLite
/// AUTOINCREMENT after.
class ShotRecord extends Equatable {
  const ShotRecord({
    required this.soldierId,
    required this.x,
    required this.y,
    required this.distance,
    required this.angle,
    required this.pattern,
    required this.createdAt,
    this.id,
    this.errorType,
  });

  /// Auto-assigned by SQLite on insert; null for unsaved records.
  final int? id;

  final String soldierId;

  /// Shot coordinates relative to target centre.
  final double x;
  final double y;

  /// Euclidean distance from target centre: √(x²+y²).
  final double distance;

  /// Angle in degrees (atan2 convention, −180…180).
  final double angle;

  /// [PatternType.name] — "horizontal" | "vertical" | "bifocal" | "scattered".
  final String pattern;

  /// [ShooterError.name] — "jerk" | "buck" | "flinch", or null if not
  /// categorised.
  final String? errorType;

  /// When this shot was recorded (UTC).
  final DateTime createdAt;

  bool get isPersisted => id != null;

  ShotRecord copyWith({
    int? id,
    String? soldierId,
    double? x,
    double? y,
    double? distance,
    double? angle,
    String? pattern,
    String? errorType,
    DateTime? createdAt,
  }) =>
      ShotRecord(
        id: id ?? this.id,
        soldierId: soldierId ?? this.soldierId,
        x: x ?? this.x,
        y: y ?? this.y,
        distance: distance ?? this.distance,
        angle: angle ?? this.angle,
        pattern: pattern ?? this.pattern,
        errorType: errorType ?? this.errorType,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props =>
      [id, soldierId, x, y, distance, angle, pattern, errorType, createdAt];

  @override
  String toString() =>
      'ShotRecord(id=$id soldier=$soldierId '
      'pattern=$pattern error=$errorType '
      'dist=${distance.toStringAsFixed(3)})';
}
