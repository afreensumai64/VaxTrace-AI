// VaxTrace AI — Offline Sync Service
// Monitors connectivity and syncs pending local data to backend

import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/child.dart';
import '../models/vaccination_record.dart';
import 'database_service.dart';
import 'api_service.dart';

enum SyncState { idle, syncing, success, failed }

class SyncService {
  final DatabaseService _db;
  final ApiService _api;
  final String deviceId;

  SyncService({
    required DatabaseService db,
    required ApiService api,
    required this.deviceId,
  })  : _db = db,
        _api = api;

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Full sync cycle: collect unsynced data → POST → mark synced
  Future<({int children, int records, List<String> errors})> syncNow() async {
    if (!await isOnline) {
      return (children: 0, records: 0, errors: ['No internet connection']);
    }

    final unsyncedChildren = await _db.getUnsyncedChildren();
    final unsyncedRecords = await _db.getUnsyncedRecords();

    if (unsyncedChildren.isEmpty && unsyncedRecords.isEmpty) {
      return (children: 0, records: 0, errors: []);
    }

    try {
      final result = await _api.syncOfflineData(
        children: unsyncedChildren,
        records: unsyncedRecords,
        deviceId: deviceId,
      );

      // Mark successfully synced items
      for (final child in unsyncedChildren) {
        await _db.markChildSynced(child.id);
      }
      for (final record in unsyncedRecords) {
        await _db.markRecordSynced(record.id);
      }

      return (
        children: result.syncedChildren,
        records: result.syncedRecords,
        errors: result.errors,
      );
    } catch (e) {
      return (children: 0, records: 0, errors: [e.toString()]);
    }
  }

  /// Download latest data from server and merge into local SQLite
  Future<void> downloadFromServer() async {
    if (!await isOnline) return;

    try {
      final serverChildren = await _api.getChildren();
      for (final child in serverChildren) {
        await _db.insertChild(child.copyWith(isSynced: true));
      }
    } catch (e) {
      // Silent fail — offline mode continues
    }
  }

  /// Watch connectivity and auto-sync when network returns
  Stream<bool> watchConnectivity() {
    return Connectivity().onConnectivityChanged.map(
      (result) => result != ConnectivityResult.none,
    );
  }
}
