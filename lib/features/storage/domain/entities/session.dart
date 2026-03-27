import 'package:equatable/equatable.dart';

import '../../../analysis/domain/entities/shot_result.dart';

/// Domain entity — immutable.  No framework dependencies.
class Session extends Equatable {
  const Session({
    required this.id,
    required this.name,
    required this.date,
    required this.createdAt,
    this.notes,
    this.shots = const [],
  });

  final String id;
  final String name;
  final DateTime date;
  final DateTime createdAt;
  final String? notes;
  final List<ShotResult> shots;

  int get totalShots => shots.length;

  double get averageScore =>
      shots.isEmpty ? 0 : shots.map((s) => s.score).reduce((a, b) => a + b) / shots.length;

  double get totalScore => shots.fold(0, (sum, s) => sum + s.score);

  Session copyWith({
    String? id,
    String? name,
    DateTime? date,
    DateTime? createdAt,
    String? notes,
    List<ShotResult>? shots,
  }) =>
      Session(
        id: id ?? this.id,
        name: name ?? this.name,
        date: date ?? this.date,
        createdAt: createdAt ?? this.createdAt,
        notes: notes ?? this.notes,
        shots: shots ?? this.shots,
      );

  @override
  List<Object?> get props => [id, name, date, createdAt, notes, shots];
}
