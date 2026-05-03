// VaxTrace AI — API Service
// REST client for FastAPI backend with Firebase Auth token injection

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/child.dart';
import '../models/vaccination_record.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class SyncResult {
  final int syncedChildren;
  final int syncedRecords;
  final List<String> errors;
  SyncResult({
    required this.syncedChildren,
    required this.syncedRecords,
    required this.errors,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) => SyncResult(
    syncedChildren: json['synced_children'] as int,
    syncedRecords: json['synced_records'] as int,
    errors: List<String>.from(json['errors'] ?? []),
  );
}

class ApiService {
  final String baseUrl;
  final Future<String?> Function() getToken;

  ApiService({
    required this.baseUrl,
    required this.getToken,
  });

  Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _get(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }

  // ─────────────────────────────────────────────
  // Children
  // ─────────────────────────────────────────────

  Future<List<Child>> getChildren({String? villageId}) async {
    final query = villageId != null ? '?village_id=$villageId' : '';
    final data = await _get('/children$query') as List;
    return data.map((e) => Child.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Child> createChild(Child child) async {
    final data = await _post('/children', child.toJson());
    return Child.fromJson(data as Map<String, dynamic>);
  }

  Future<Child> updateChild(Child child) async {
    final data = await _put('/children/${child.id}', child.toJson());
    return Child.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Child>> getHighRiskChildren() async {
    final data = await _get('/children/high-risk') as Map<String, dynamic>;
    final list = data['children'] as List;
    return list.map((e) => Child.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Child>> getDailyRoute({
    double clinicLat = 30.3753,
    double clinicLng = 72.8656,
  }) async {
    final data = await _get(
      '/children/route?clinic_lat=$clinicLat&clinic_lng=$clinicLng',
    ) as Map<String, dynamic>;
    final list = data['children'] as List;
    return list.map((e) => Child.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> getVillageStats() async {
    final data = await _get('/children/village-stats') as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['villages'] as List);
  }

  // ─────────────────────────────────────────────
  // Vaccination Records
  // ─────────────────────────────────────────────

  Future<List<VaccinationRecord>> getRecords(String childId) async {
    final data = await _get('/vaccines/$childId') as List;
    return data.map((e) => VaccinationRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<VaccinationRecord> createRecord(VaccinationRecord record) async {
    final data = await _post('/vaccines', record.toJson());
    return VaccinationRecord.fromJson(data as Map<String, dynamic>);
  }

  // ─────────────────────────────────────────────
  // Sync
  // ─────────────────────────────────────────────

  Future<SyncResult> syncOfflineData({
    required List<Child> children,
    required List<VaccinationRecord> records,
    required String deviceId,
  }) async {
    final payload = {
      'device_id': deviceId,
      'synced_at': DateTime.now().toIso8601String(),
      'children': children.map((c) => c.toJson()).toList(),
      'vaccination_records': records.map((r) => r.toJson()).toList(),
    };
    final data = await _post('/sync', payload);
    return SyncResult.fromJson(data as Map<String, dynamic>);
  }

  // ─────────────────────────────────────────────
  // Risk prediction
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> predictRisk({
    required String childId,
    required double distanceKm,
    required int daysSinceLastDose,
  }) async {
    return await _post('/predict/risk', {
      'child_id': childId,
      'distance_from_clinic_km': distanceKm,
      'days_since_last_dose': daysSinceLastDose,
    }) as Map<String, dynamic>;
  }
}
