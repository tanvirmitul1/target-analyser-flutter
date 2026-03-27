import '../../../../core/constants/db_constants.dart';
import '../../../analysis/domain/entities/shot_result.dart';
import '../../domain/entities/session.dart';

/// Data-layer DTO — converts between [Session] and SQLite row maps.
class SessionModel {
  const SessionModel({
    required this.id,
    required this.name,
    required this.date,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String name;
  final String date;
  final String createdAt;
  final String? notes;

  factory SessionModel.fromMap(Map<String, dynamic> map) => SessionModel(
        id: map[DbConstants.colSessionId] as String,
        name: map[DbConstants.colSessionName] as String,
        date: map[DbConstants.colSessionDate] as String,
        createdAt: map[DbConstants.colSessionCreatedAt] as String,
        notes: map[DbConstants.colSessionNotes] as String?,
      );

  Map<String, dynamic> toMap() => {
        DbConstants.colSessionId: id,
        DbConstants.colSessionName: name,
        DbConstants.colSessionDate: date,
        DbConstants.colSessionCreatedAt: createdAt,
        DbConstants.colSessionNotes: notes,
      };

  Session toDomain({List<ShotResult> shots = const []}) => Session(
        id: id,
        name: name,
        date: DateTime.parse(date),
        createdAt: DateTime.parse(createdAt),
        notes: notes,
        shots: shots,
      );

  factory SessionModel.fromDomain(Session s) => SessionModel(
        id: s.id,
        name: s.name,
        date: s.date.toIso8601String(),
        createdAt: s.createdAt.toIso8601String(),
        notes: s.notes,
      );
}
