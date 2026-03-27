import 'package:equatable/equatable.dart';

/// Domain entity representing a registered soldier.
///
/// Deliberately thin — the business key is the [id] (e.g. service number).
/// Additional profile data can be added as nullable fields without breaking
/// existing rows (via ALTER TABLE ADD COLUMN in a migration).
class Soldier extends Equatable {
  const Soldier({required this.id});

  /// Opaque identifier — typically a service/personnel number.
  final String id;

  Soldier copyWith({String? id}) => Soldier(id: id ?? this.id);

  @override
  List<Object?> get props => [id];

  @override
  String toString() => 'Soldier($id)';
}
