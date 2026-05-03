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
// LOCAL DEV: physical device on same WiFi as this PC
// RENDER DEPLOY: change back to 'https://vaxtrace-api.onrender.com'
// ─────────────────────────────────────────────────────────
const String _kBaseUrl = 'http://10.226.186.47:8000';

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
// Single child by ID (SQLite — for reactive updates after prediction)
// ─────────────────────────────────────────────

final childByIdProvider = FutureProvider.family<Child?, String>((ref, childId) async {
  ref.watch(childrenProvider);
  final db = ref.read(databaseServiceProvider);
  return db.getChild(childId);
});

// ─────────────────────────────────────────────
// Risk prediction + AI explanation (per child)
// ─────────────────────────────────────────────

class RiskPredictionState {
  final bool isLoading;
  final String? error;
  const RiskPredictionState({this.isLoading = false, this.error});
}

class RiskPredictionNotifier extends StateNotifier<RiskPredictionState> {
  RiskPredictionNotifier(this._api, this._db, this._ref)
      : super(const RiskPredictionState());

  final ApiService _api;
  final DatabaseService _db;
  final Ref _ref;

  Future<void> predict({
    required String childId,
    required double distanceKm,
    required int daysSinceLastDose,
  }) async {
    state = const RiskPredictionState(isLoading: true);
    try {
      final result = await _api.predictRisk(
        childId: childId,
        distanceKm: distanceKm,
        daysSinceLastDose: daysSinceLastDose,
      );
      final explanation = result['explanation'] as String?;
      if (explanation != null && explanation.isNotEmpty) {
        await _db.saveExplanation(childId, explanation);
      }
      _ref.invalidate(childByIdProvider(childId));
      _ref.invalidate(highRiskChildrenProvider);
      _ref.invalidate(childrenProvider);
      state = const RiskPredictionState();
    } catch (e) {
      state = RiskPredictionState(error: e.toString());
    }
  }
}

final riskPredictionProvider = StateNotifierProvider.family<
    RiskPredictionNotifier, RiskPredictionState, String>((ref, childId) {
  return RiskPredictionNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(databaseServiceProvider),
    ref,
  );
});

// ─────────────────────────────────────────────
// Village stats (NGO dashboard — requires online)
// ─────────────────────────────────────────────

final villageStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getVillageStats();
});

// ─────────────────────────────────────────────
// Language preference
// ─────────────────────────────────────────────

final languageProvider = StateProvider<AppLanguage>((ref) => AppLanguage.english);
