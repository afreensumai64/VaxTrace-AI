// VaxTrace AI — SQLite Database Service
// Offline-first: all data persists locally before syncing to backend

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/child.dart';
import '../models/vaccination_record.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vaxtrace.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE children (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        date_of_birth TEXT NOT NULL,
        guardian_name TEXT NOT NULL,
        guardian_phone TEXT NOT NULL,
        village_id TEXT NOT NULL,
        village_name TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        distance_from_clinic_km REAL NOT NULL DEFAULT 0,
        last_dose_date TEXT,
        last_vaccine_name TEXT,
        next_due_date TEXT,
        risk_score REAL NOT NULL DEFAULT 0,
        risk_level TEXT NOT NULL DEFAULT 'low',
        is_high_risk INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        client_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        explanation TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vaccination_records (
        id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        vaccine_name TEXT NOT NULL,
        dose_number INTEGER NOT NULL DEFAULT 1,
        date_administered TEXT NOT NULL,
        administered_by TEXT NOT NULL,
        batch_number TEXT,
        clinic_name TEXT,
        notes TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        client_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_children_village ON children(village_id)');
    await db.execute('CREATE INDEX idx_children_risk ON children(risk_score DESC)');
    await db.execute('CREATE INDEX idx_records_child ON vaccination_records(child_id)');
    await db.execute('CREATE INDEX idx_unsynced_children ON children(is_synced) WHERE is_synced = 0');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE children ADD COLUMN explanation TEXT');
    }
  }

  // ─────────────────────────────────────────────
  // Children CRUD
  // ─────────────────────────────────────────────

  Future<void> insertChild(Child child) async {
    final db = await database;
    await db.insert(
      'children',
      child.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateChild(Child child) async {
    final db = await database;
    await db.update(
      'children',
      child.toMap(),
      where: 'id = ?',
      whereArgs: [child.id],
    );
  }

  Future<void> deleteChild(String id) async {
    final db = await database;
    await db.delete('children', where: 'id = ?', whereArgs: [id]);
  }

  Future<Child?> getChild(String id) async {
    final db = await database;
    final maps = await db.query('children', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Child.fromMap(maps.first);
  }

  Future<List<Child>> getAllChildren({String? villageId}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (villageId != null) {
      maps = await db.query(
        'children',
        where: 'village_id = ?',
        whereArgs: [villageId],
        orderBy: 'risk_score DESC',
      );
    } else {
      maps = await db.query('children', orderBy: 'risk_score DESC');
    }
    return maps.map(Child.fromMap).toList();
  }

  Future<List<Child>> getHighRiskChildren({int limit = 20}) async {
    final db = await database;
    final maps = await db.query(
      'children',
      where: 'is_high_risk = 1',
      orderBy: 'risk_score DESC',
      limit: limit,
    );
    return maps.map(Child.fromMap).toList();
  }

  Future<List<Child>> getUnsyncedChildren() async {
    final db = await database;
    final maps = await db.query(
      'children',
      where: 'is_synced = 0',
    );
    return maps.map(Child.fromMap).toList();
  }

  Future<void> markChildSynced(String id) async {
    final db = await database;
    await db.update(
      'children',
      {'is_synced': 1, 'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveExplanation(String childId, String explanation) async {
    final db = await database;
    await db.update(
      'children',
      {'explanation': explanation},
      where: 'id = ?',
      whereArgs: [childId],
    );
  }

  // ─────────────────────────────────────────────
  // Vaccination Records CRUD
  // ─────────────────────────────────────────────

  Future<void> insertRecord(VaccinationRecord record) async {
    final db = await database;
    await db.insert(
      'vaccination_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<VaccinationRecord>> getRecordsForChild(String childId) async {
    final db = await database;
    final maps = await db.query(
      'vaccination_records',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'date_administered DESC',
    );
    return maps.map(VaccinationRecord.fromMap).toList();
  }

  Future<List<VaccinationRecord>> getUnsyncedRecords() async {
    final db = await database;
    final maps = await db.query(
      'vaccination_records',
      where: 'is_synced = 0',
    );
    return maps.map(VaccinationRecord.fromMap).toList();
  }

  Future<void> markRecordSynced(String id) async {
    final db = await database;
    await db.update(
      'vaccination_records',
      {'is_synced': 1, 'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─────────────────────────────────────────────
  // Stats
  // ─────────────────────────────────────────────

  Future<Map<String, int>> getStats() async {
    final db = await database;
    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM children')) ?? 0;
    final highRisk = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM children WHERE is_high_risk = 1')) ?? 0;
    final unsynced = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM children WHERE is_synced = 0')) ?? 0;
    final overdue = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM children WHERE next_due_date IS NOT NULL AND next_due_date < date('now')"
        )) ?? 0;
    return {
      'total': total,
      'highRisk': highRisk,
      'unsynced': unsynced,
      'overdue': overdue,
    };
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
