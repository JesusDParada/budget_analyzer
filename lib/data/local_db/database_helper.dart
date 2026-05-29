import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:budget_analyzer/domain/models/project.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';
import 'package:budget_analyzer/domain/models/capitulo.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('budget_analyzer.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Drop all old tables and recreate with the new unified schema (v7)
    if (oldVersion < 7) {
      await db.execute('DROP TABLE IF EXISTS cut_insumo_purchases');
      await db.execute('DROP TABLE IF EXISTS cut_records');
      await db.execute('DROP TABLE IF EXISTS apu_items');
      await db.execute('DROP TABLE IF EXISTS insumos');
      await db.execute('DROP TABLE IF EXISTS apus');
      await db.execute('DROP TABLE IF EXISTS activities');
      await db.execute('DROP TABLE IF EXISTS field_progress');
      await db.execute('DROP TABLE IF EXISTS inventory_issues');
      await db.execute('DROP TABLE IF EXISTS capitulos');
      await db.execute('DROP TABLE IF EXISTS projects');

      await _createDB(db, newVersion);
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const doubleType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE projects (
  id $idType,
  name $textType UNIQUE,
  date $textType
)
''');

    await db.execute('''
CREATE TABLE capitulos (
  id $idType,
  projectId INTEGER NOT NULL,
  numero INTEGER NOT NULL,
  nombre $textType,
  FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE activities (
  id $idType,
  projectId INTEGER NOT NULL,
  capituloId INTEGER,
  codigo $textType,
  nombre $textType,
  unidad $textType,
  cantidad $doubleType,
  valorUnitario $doubleType,
  bac $doubleType,
  memoriaJson TEXT,
  detalleJson TEXT,
  FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE,
  FOREIGN KEY (capituloId) REFERENCES capitulos (id) ON DELETE SET NULL
)
''');

    await db.execute('''
CREATE TABLE insumos (
  id $idType,
  activityId INTEGER NOT NULL,
  descripcion $textType,
  unidad $textType,
  valorUnitario $doubleType,
  cantidad $doubleType,
  FOREIGN KEY (activityId) REFERENCES activities (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE cut_records (
  id $textType PRIMARY KEY,
  activityId INTEGER NOT NULL,
  cutNumber INTEGER NOT NULL,
  activityQuantity $doubleType,
  date $textType,
  FOREIGN KEY (activityId) REFERENCES activities (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE cut_insumo_purchases (
  id $textType PRIMARY KEY,
  cutRecordId $textType,
  insumoDescription $textType,
  realPrice $doubleType,
  purchasedQuantity $doubleType,
  consumedQuantity $doubleType,
  FOREIGN KEY (cutRecordId) REFERENCES cut_records (id) ON DELETE CASCADE
)
''');
  }

  // --- Operaciones para Proyectos ---

  Future<int> insertProject(Project project) async {
    final db = await instance.database;
    final maps = await db.query('projects', where: 'name = ?', whereArgs: [project.name]);
    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    }
    return await db.insert('projects', project.toMap());
  }

  Future<List<Project>> getAllProjects() async {
    final db = await instance.database;
    final result = await db.query('projects');
    return result.map((json) => Project.fromMap(json)).toList();
  }

  // --- Operaciones para Capítulos ---

  Future<List<Capitulo>> insertCapitulos(List<Capitulo> capitulos) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var cap in capitulos) {
      batch.insert('capitulos', cap.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final results = await batch.commit();
    List<Capitulo> savedCapitulos = [];
    for (int i = 0; i < capitulos.length; i++) {
      savedCapitulos.add(Capitulo(
        id: results[i] as int,
        projectId: capitulos[i].projectId,
        numero: capitulos[i].numero,
        nombre: capitulos[i].nombre,
      ));
    }
    return savedCapitulos;
  }

  Future<List<Capitulo>> getCapitulosByProject(int projectId) async {
    final db = await instance.database;
    final result = await db.query('capitulos', where: 'projectId = ?', whereArgs: [projectId], orderBy: 'numero ASC');
    return result.map((json) => Capitulo.fromMap(json)).toList();
  }

  Future<List<Capitulo>> getAllCapitulos() async {
    final db = await instance.database;
    final result = await db.query('capitulos', orderBy: 'numero ASC');
    return result.map((json) => Capitulo.fromMap(json)).toList();
  }

  // --- Operaciones para APUs / Activities ---

  Future<List<Apu>> insertApus(List<Apu> apus) async {
    final db = await instance.database;
    final batch = db.batch();
    
    // First, insert activities to get their auto-incremented IDs
    for (var apu in apus) {
      batch.insert('activities', apu.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final results = await batch.commit();
    
    List<Apu> savedApus = [];
    final insumoBatch = db.batch();
    
    for (int i = 0; i < apus.length; i++) {
      final activityId = results[i] as int;
      savedApus.add(Apu(
        id: activityId,
        codigo: apus[i].codigo,
        nombre: apus[i].nombre,
        unidad: apus[i].unidad,
        projectId: apus[i].projectId,
        capituloId: apus[i].capituloId,
        cantidad: apus[i].cantidad,
        valorUnitario: apus[i].valorUnitario,
        bac: apus[i].bac,
        memoriaJson: apus[i].memoriaJson,
        detalleJson: apus[i].detalleJson,
        insumos: apus[i].insumos,
      ));
      
      for (var insumo in apus[i].insumos) {
        // Ensure activityId is linked to the newly created activity
        final map = insumo.toMap();
        map['activityId'] = activityId;
        // removing null ID just in case
        map.remove('id');
        insumoBatch.insert('insumos', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await insumoBatch.commit(noResult: true);
    
    return savedApus;
  }

  Future<List<Apu>> getAllApus() async {
    final db = await instance.database;
    final activityMaps = await db.query('activities');
    final insumoMaps = await db.query('insumos');

    List<Apu> result = [];
    for (var activityMap in activityMaps) {
      final activityId = activityMap['id'] as int;
      
      final activityInsumos = insumoMaps
          .where((i) => i['activityId'] == activityId)
          .map((map) => Insumo.fromMap(map))
          .toList();

      result.add(Apu.fromMap(activityMap, insumos: activityInsumos));
    }
    return result;
  }

  Future<List<Apu>> getApusByProject(int projectId) async {
    final db = await instance.database;
    final activityMaps = await db.query('activities', where: 'projectId = ?', whereArgs: [projectId]);
    final insumoMaps = await db.query('insumos');

    List<Apu> result = [];
    for (var activityMap in activityMaps) {
      final activityId = activityMap['id'] as int;
      
      final activityInsumos = insumoMaps
          .where((i) => i['activityId'] == activityId)
          .map((map) => Insumo.fromMap(map))
          .toList();

      result.add(Apu.fromMap(activityMap, insumos: activityInsumos));
    }
    return result;
  }

  Future<List<Insumo>> getAllInsumos() async {
    final db = await instance.database;
    final result = await db.query('insumos');
    return result.map((json) => Insumo.fromMap(json)).toList();
  }

  // --- Operaciones de Cortes (EVM) ---

  Future<void> insertCutRecord(Map<String, dynamic> cutMap, List<Map<String, dynamic>> purchases) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('cut_records', cutMap, conflictAlgorithm: ConflictAlgorithm.replace);
      for (var purchase in purchases) {
        await txn.insert('cut_insumo_purchases', purchase, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCutRecordsForActivity(int activityId) async {
    final db = await instance.database;
    return await db.query('cut_records', where: 'activityId = ?', whereArgs: [activityId], orderBy: 'cutNumber ASC');
  }

  Future<List<Map<String, dynamic>>> getPurchasesForCut(String cutRecordId) async {
    final db = await instance.database;
    return await db.query('cut_insumo_purchases', where: 'cutRecordId = ?', whereArgs: [cutRecordId]);
  }
}
