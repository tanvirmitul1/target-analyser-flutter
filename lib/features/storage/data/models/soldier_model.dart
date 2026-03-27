import '../../../../core/constants/db_constants.dart';
import '../../domain/entities/soldier.dart';

/// SQLite DTO for the `soldiers` table.
class SoldierModel {
  const SoldierModel({required this.id});

  final String id;

  factory SoldierModel.fromMap(Map<String, dynamic> map) =>
      SoldierModel(id: map[DbConstants.colSoldierId] as String);

  Map<String, dynamic> toMap() => {DbConstants.colSoldierId: id};

  Soldier toDomain() => Soldier(id: id);

  factory SoldierModel.fromDomain(Soldier s) => SoldierModel(id: s.id);
}
