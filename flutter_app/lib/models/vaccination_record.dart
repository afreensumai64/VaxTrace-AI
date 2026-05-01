// VaxTrace AI — VaccinationRecord Flutter Model
// mirrors backend VaccinationRecordORM exactly

import 'package:flutter/foundation.dart';
import 'child.dart';

@immutable
class VaccinationRecord {
  final String id;
  final String childId;
  final String vaccineName;
  final int doseNumber;
  final DateTime dateAdministered;
  final String administeredBy;
  final String? batchNumber;
  final String? clinicName;
  final String? notes;
  final bool isSynced;
  final SyncStatus syncStatus;
  final String? clientId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VaccinationRecord({
    required this.id,
    required this.childId,
    required this.vaccineName,
    required this.doseNumber,
    required this.dateAdministered,
    required this.administeredBy,
    this.batchNumber,
    this.clinicName,
    this.notes,
    required this.isSynced,
    required this.syncStatus,
    this.clientId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VaccinationRecord.fromJson(Map<String, dynamic> json) {
    return VaccinationRecord(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      vaccineName: json['vaccine_name'] as String,
      doseNumber: json['dose_number'] as int? ?? 1,
      dateAdministered: DateTime.parse(json['date_administered'] as String),
      administeredBy: json['administered_by'] as String,
      batchNumber: json['batch_number'] as String?,
      clinicName: json['clinic_name'] as String?,
      notes: json['notes'] as String?,
      isSynced: json['is_synced'] as bool? ?? false,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == (json['sync_status'] as String? ?? 'pending'),
        orElse: () => SyncStatus.pending,
      ),
      clientId: json['client_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'child_id': childId,
    'vaccine_name': vaccineName,
    'dose_number': doseNumber,
    'date_administered': _dateOnly(dateAdministered),
    'administered_by': administeredBy,
    'batch_number': batchNumber,
    'clinic_name': clinicName,
    'notes': notes,
    'is_synced': isSynced,
    'sync_status': syncStatus.name,
    'client_id': clientId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    'child_id': childId,
    'vaccine_name': vaccineName,
    'dose_number': doseNumber,
    'date_administered': _dateOnly(dateAdministered),
    'administered_by': administeredBy,
    'batch_number': batchNumber,
    'clinic_name': clinicName,
    'notes': notes,
    'is_synced': isSynced ? 1 : 0,
    'sync_status': syncStatus.name,
    'client_id': clientId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory VaccinationRecord.fromMap(Map<String, dynamic> map) {
    return VaccinationRecord(
      id: map['id'] as String,
      childId: map['child_id'] as String,
      vaccineName: map['vaccine_name'] as String,
      doseNumber: map['dose_number'] as int? ?? 1,
      dateAdministered: DateTime.parse(map['date_administered'] as String),
      administeredBy: map['administered_by'] as String,
      batchNumber: map['batch_number'] as String?,
      clinicName: map['clinic_name'] as String?,
      notes: map['notes'] as String?,
      isSynced: (map['is_synced'] as int) == 1,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == (map['sync_status'] as String? ?? 'pending'),
        orElse: () => SyncStatus.pending,
      ),
      clientId: map['client_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static String _dateOnly(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is VaccinationRecord && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
