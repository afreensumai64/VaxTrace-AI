// VaxTrace AI — Riverpod Providers
// Auth: JWT via JwtAuthService (zero-cost, no Firebase required)
// Swap _kBaseUrl below after deploying to Render.com

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/child.dart';
import '../models/vaccination_record.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/ocr_service.dart';
import '../services/tts_service.dart';
import '../services/jwt_auth_service.dart';

// ─────────────────────────────────────────────────────────
// ⚠️  UPDATE THIS after deploying to Render.com:
//     e.g. 'https://vaxtrace-api.onrender.com'
// ─────────────────────────────────────────────────────────
const String _kBaseUrl = 'https://vaxtrace-api.onrender.com';

// ─────────────────────────────────────────────
// Core services
// ─────────────────────────────────────────────

final jwtAuthServiceProvider = Provider<JwtAuthService>((ref) {
  final service = JwtAuthService(baseUrl: _kBaseUrl);
  // Init persisted session on app start (async, non-blocking)
  service.init();
  return service;
});

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final authService = ref.watch(jwtAuthServiceProvider);
  return ApiService(
    baseUrl: _kBaseUrl,
    getToken: () => authService.getIdToken(),
  );
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  final api = ref.watch(apiServiceProvider);
  return SyncService(db: db, api: api, deviceId: 'device-001');
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  final ocr = OcrService();
  ref.onDispose(() => ocr.dispose());
  return ocr;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final tts = TtsService();
  ref.onDispose(() => tts.dispose());
  return tts;
});

// ─────────────────────────────────────────────
// Auth state — JWT stream (replaces Firebase authStateChanges)
// ─────────────────────────────────────────────

final authStateProvider = StreamProvider<JwtUser?>((ref) {
  return ref.watch(jwtAuthServiceProvider).authStateChanges;
});

// ─────────────────────────────────────────────
// Children list (SQLite — offline-first)
// ─────────────────────────────────────────────

class ChildrenNotifier extends AsyncNotifier<List<Child>> {
  @override
  Future<List<Child>> build() async {
    final db = ref.watch(databaseServiceProvider);
    return db.getAllChildren();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);
      return db.getAllChildren();
    });
  }

  Future<void> addChild(Child child) async {
    final db = ref.read(databaseServiceProvider);
    await db.insertChild(child);
    await refresh();
  }

  Future<void> updateChild(Child child) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateChild(child);
    await refresh();
  }

  Future<void> deleteChild(String id) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteChild(id);
    await refresh();
  }
}

final childrenProvider =
    AsyncNotifierProvider<ChildrenNotifier, List<Child>>(ChildrenNotifier.new);

// ─────────────────────────────────────────────
// High-risk children
// ─────────────────────────────────────────────

final highRiskChildrenProvider = FutureProvider<List<Child>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return db.getHighRiskChildren();
});

// ─────────────────────────────────────────────
// Vaccination records for a child
// ─────────────────────────────────────────────

final vaccinationRecordsProvider =
    FutureProvider.family<List<VaccinationRecord>, String>((ref, childId) async {
  final db = ref.watch(databaseServiceProvider);
  return db.getRecordsForChild(childId);
});

// ─────────────────────────────────────────────
// Dashboard stats
// ─────────────────────────────────────────────

final dashboardStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(childrenProvider);
  final db = ref.read(databaseServiceProvider);
  return db.getStats();
});

// ─────────────────────────────────────────────
// Sync state
// ─────────────────────────────────────────────

class SyncNotifier extends StateNotifier<AsyncValue<String>> {
  SyncNotifier(this._syncService) : super(const AsyncData('Ready'));

  final SyncService _syncService;

  Future<void> sync() async {
    state = const AsyncLoading();
    try {
      final result = await _syncService.syncNow();
      state = result.errors.isEmpty
          ? AsyncData('Synced ${result.children} children, ${result.records} records')
          : AsyncData('Partial sync: ${result.errors.first}');
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, AsyncValue<String>>((ref) {
  return SyncNotifier(ref.watch(syncServiceProvider));
});

final connectivityProvider = StreamProvider<bool>((ref) {
  return ref.watch(syncServiceProvider).watchConnectivity();
});

// ─────────────────────────────────────────────
// OCR state
// ─────────────────────────────────────────────

class OcrState {
  final bool isProcessing;
  final OcrResult? result;
  final String? error;
  const OcrState({this.isProcessing = false, this.result, this.error});
}

class OcrNotifier extends StateNotifier<OcrState> {
  OcrNotifier(this._ocr) : super(const OcrState());

  final OcrService _ocr;

  Future<void> scan(dynamic imageFile) async {
    state = const OcrState(isProcessing: true);
    try {
      final result = await _ocr.scanVaccinationCard(imageFile);
      state = OcrState(result: result);
    } catch (e) {
      state = OcrState(error: e.toString());
    }
  }

  void reset() => state = const OcrState();
}

final ocrNotifierProvider =
    StateNotifierProvider<OcrNotifier, OcrState>((ref) {
  return OcrNotifier(ref.watch(ocrServiceProvider));
});

// ─────────────────────────────────────────────
// Language preference
// ─────────────────────────────────────────────

final languageProvider = StateProvider<AppLanguage>((ref) => AppLanguage.english);
