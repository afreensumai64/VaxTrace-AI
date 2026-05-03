// VaxTrace AI — Flutter Child Model
// Schema contract: mirrors backend app/models.py ChildBase exactly.

import 'package:flutter/foundation.dart';

enum RiskLevel { low, medium, high, critical }
enum SyncStatus { pending, synced, failed }

extension RiskLevelExtension on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.low: return 'Low';
      case RiskLevel.medium: return 'Medium';
      case RiskLevel.high: return 'High';
      case RiskLevel.critical: return 'Critical';
    }
  }

  String get colorHex {
    switch (this) {
      case RiskLevel.low: return '#4CAF50';
      case RiskLevel.medium: return '#FFC107';
      case RiskLevel.high: return '#FF5722';
      case RiskLevel.critical: return '#D32F2F';
    }
  }
}

@immutable
class Child {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String guardianName;
  final String guardianPhone;
  final String villageId;
  final String villageName;
  final double? latitude;
  final double? longitude;
  final double distanceFromClinicKm;
  final DateTime? lastDoseDate;
  final String? lastVaccineName;
  final DateTime? nextDueDate;
  final double riskScore;
  final RiskLevel riskLevel;
  final bool isHighRisk;
  final bool isSynced;
  final SyncStatus syncStatus;
  final String? clientId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? explanation;

  const Child({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.guardianName,
    required this.guardianPhone,
    required this.villageId,
    required this.villageName,
    this.latitude,
    this.longitude,
    required this.distanceFromClinicKm,
    this.lastDoseDate,
    this.lastVaccineName,
    this.nextDueDate,
    required this.riskScore,
    required this.riskLevel,
    required this.isHighRisk,
    required this.isSynced,
    required this.syncStatus,
    this.clientId,
    required this.createdAt,
    required this.updatedAt,
    this.explanation,
  });

  int get ageInMonths {
    final now = DateTime.now();
    return (now.year - dateOfBirth.year) * 12 + (now.month - dateOfBirth.month);
  }

  int get daysSinceLastDose =>
      lastDoseDate == null ? 9999 : DateTime.now().difference(lastDoseDate!).inDays;

  int get daysUntilNextDose =>
      nextDueDate == null ? -1 : nextDueDate!.difference(DateTime.now()).inDays;

  bool get isOverdue => nextDueDate != null && nextDueDate!.isBefore(DateTime.now());

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] as String,
      name: json['name'] as String,
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      guardianName: json['guardian_name'] as String,
      guardianPhone: json['guardian_phone'] as String,
      villageId: json['village_id'] as String,
      villageName: json['village_name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceFromClinicKm: (json['distance_from_clinic_km'] as num).toDouble(),
      lastDoseDate: json['last_dose_date'] != null
          ? DateTime.parse(json['last_dose_date'] as String) : null,
      lastVaccineName: json['last_vaccine_name'] as String?,
      nextDueDate: json['next_due_date'] != null
          ? DateTime.parse(json['next_due_date'] as String) : null,
      riskScore: (json['risk_score'] as num).toDouble(),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == (json['risk_level'] as String),
        orElse: () => RiskLevel.low,
      ),
      isHighRisk: json['is_high_risk'] as bool? ?? false,
      isSynced: json['is_synced'] as bool? ?? false,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == (json['sync_status'] as String? ?? 'pending'),
        orElse: () => SyncStatus.pending,
      ),
      clientId: json['client_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      explanation: json['explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date_of_birth': _dateOnly(dateOfBirth),
    'guardian_name': guardianName,
    'guardian_phone': guardianPhone,
    'village_id': villageId,
    'village_name': villageName,
    'latitude': latitude,
    'longitude': longitude,
    'distance_from_clinic_km': distanceFromClinicKm,
    'last_dose_date': lastDoseDate != null ? _dateOnly(lastDoseDate!) : null,
    'last_vaccine_name': lastVaccineName,
    'next_due_date': nextDueDate != null ? _dateOnly(nextDueDate!) : null,
    'risk_score': riskScore,
    'risk_level': riskLevel.name,
    'is_high_risk': isHighRisk,
    'is_synced': isSynced,
    'sync_status': syncStatus.name,
    'client_id': clientId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'explanation': explanation,
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'date_of_birth': _dateOnly(dateOfBirth),
    'guardian_name': guardianName,
    'guardian_phone': guardianPhone,
    'village_id': villageId,
    'village_name': villageName,
    'latitude': latitude,
    'longitude': longitude,
    'distance_from_clinic_km': distanceFromClinicKm,
    'last_dose_date': lastDoseDate != null ? _dateOnly(lastDoseDate!) : null,
    'last_vaccine_name': lastVaccineName,
    'next_due_date': nextDueDate != null ? _dateOnly(nextDueDate!) : null,
    'risk_score': riskScore,
    'risk_level': riskLevel.name,
    'is_high_risk': isHighRisk ? 1 : 0,
    'is_synced': isSynced ? 1 : 0,
    'sync_status': syncStatus.name,
    'client_id': clientId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'explanation': explanation,
  };

  factory Child.fromMap(Map<String, dynamic> map) {
    return Child(
      id: map['id'] as String,
      name: map['name'] as String,
      dateOfBirth: DateTime.parse(map['date_of_birth'] as String),
      guardianName: map['guardian_name'] as String,
      guardianPhone: map['guardian_phone'] as String,
      villageId: map['village_id'] as String,
      villageName: map['village_name'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      distanceFromClinicKm: (map['distance_from_clinic_km'] as num).toDouble(),
      lastDoseDate: map['last_dose_date'] != null
          ? DateTime.parse(map['last_dose_date'] as String) : null,
      lastVaccineName: map['last_vaccine_name'] as String?,
      nextDueDate: map['next_due_date'] != null
          ? DateTime.parse(map['next_due_date'] as String) : null,
      riskScore: (map['risk_score'] as num).toDouble(),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == (map['risk_level'] as String),
        orElse: () => RiskLevel.low,
      ),
      isHighRisk: (map['is_high_risk'] as int) == 1,
      isSynced: (map['is_synced'] as int) == 1,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == (map['sync_status'] as String? ?? 'pending'),
        orElse: () => SyncStatus.pending,
      ),
      clientId: map['client_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      explanation: map['explanation'] as String?,
    );
  }

  Child copyWith({
    String? id, String? name, DateTime? dateOfBirth, String? guardianName,
    String? guardianPhone, String? villageId, String? villageName,
    double? latitude, double? longitude, double? distanceFromClinicKm,
    DateTime? lastDoseDate, String? lastVaccineName, DateTime? nextDueDate,
    double? riskScore, RiskLevel? riskLevel, bool? isHighRisk,
    bool? isSynced, SyncStatus? syncStatus, String? clientId,
    DateTime? createdAt, DateTime? updatedAt, String? explanation,
  }) {
    return Child(
      id: id ?? this.id, name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      villageId: villageId ?? this.villageId,
      villageName: villageName ?? this.villageName,
      latitude: latitude ?? this.latitude, longitude: longitude ?? this.longitude,
      distanceFromClinicKm: distanceFromClinicKm ?? this.distanceFromClinicKm,
      lastDoseDate: lastDoseDate ?? this.lastDoseDate,
      lastVaccineName: lastVaccineName ?? this.lastVaccineName,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      riskScore: riskScore ?? this.riskScore, riskLevel: riskLevel ?? this.riskLevel,
      isHighRisk: isHighRisk ?? this.isHighRisk, isSynced: isSynced ?? this.isSynced,
      syncStatus: syncStatus ?? this.syncStatus, clientId: clientId ?? this.clientId,
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      explanation: explanation ?? this.explanation,
    );
  }

  static String _dateOnly(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Child && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Child(id: $id, name: $name, risk: ${riskLevel.name})';
}
