import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:budget_analyzer/domain/models/project.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';

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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    const textType = 'TEXT NOT NULL';
    const doubleType = 'REAL NOT NULL';
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';

    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS inventory_issues (
  id $textType PRIMARY KEY,
  apuCodigo $textType,
  materialName $textType,
  quantity $doubleType,
  totalCost $doubleType,
  date $textType,
  FOREIGN KEY (apuCodigo) REFERENCES apus (codigo) ON DELETE CASCADE
)
''');

      await db.execute('''
CREATE TABLE IF NOT EXISTS field_progress (
  id $textType PRIMARY KEY,
  apuCodigo $textType,
  quantity $doubleType,
  date $textType,
  FOREIGN KEY (apuCodigo) REFERENCES apus (codigo) ON DELETE CASCADE
)
''');
    }

    if (oldVersion < 3) {
      // Recreate schema to support projects and detailed sheets
      await db.execute('DROP TABLE IF EXISTS apu_items');
      await db.execute('DROP TABLE IF EXISTS apus');
      await db.execute('DROP TABLE IF EXISTS projects');

      await db.execute('''
CREATE TABLE projects (
  id $idType,
  name $textType UNIQUE,
  date $textType
)
''');

      await db.execute('''
CREATE TABLE apus (
  id $idType,
  projectId INTEGER NOT NULL,
  codigo $textType,
  nombre $textType,
  unidad $textType,
  cantidad $doubleType,
  valorUnitario $doubleType,
  bac $doubleType,
  memoriaJson TEXT,
  detalleJson TEXT,
  FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
)
''');

      await db.execute('''
CREATE TABLE apu_items (
  id $idType,
  apuCodigo $textType,
  insumoCodigo $textType,
  cantidad $doubleType,
  FOREIGN KEY (apuCodigo) REFERENCES apus (codigo) ON DELETE CASCADE,
  FOREIGN KEY (insumoCodigo) REFERENCES insumos (codigo) ON DELETE CASCADE
)
''');
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
CREATE TABLE insumos (
  id $idType,
  codigo $textType UNIQUE,
  descripcion $textType,
  unidad $textType,
  valorUnitario $doubleType,
  tipo $textType
)
''');

    await db.execute('''
CREATE TABLE apus (
  id $idType,
  projectId INTEGER NOT NULL,
  codigo $textType,
  nombre $textType,
  unidad $textType,
  cantidad $doubleType,
  valorUnitario $doubleType,
  bac $doubleType,
  memoriaJson TEXT,
  detalleJson TEXT,
  FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE apu_items (
  id $idType,
  apuCodigo $textType,
  insumoCodigo $textType,
  cantidad $doubleType,
  FOREIGN KEY (apuCodigo) REFERENCES apus (codigo) ON DELETE CASCADE,
  FOREIGN KEY (insumoCodigo) REFERENCES insumos (codigo) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE inventory_issues (
  id $textType PRIMARY KEY,
  apuCodigo $textType,
  materialName $textType,
  quantity $doubleType,
  totalCost $doubleType,
  date $textType,
  FOREIGN KEY (apuCodigo) REFERENCES apus (codigo) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE field_progress (
  id $textType PRIMARY KEY,
  apuCodigo $textType,
  quantity $doubleType,
  date $textType,
  FOREIGN KEY (apuCodigo) REFERENCES apus (codigo) ON DELETE CASCADE
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

  // --- Operaciones para Insumos ---

  Future<void> insertInsumos(List<Insumo> insumos) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var insumo in insumos) {
      batch.insert('insumos', insumo.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Insumo>> getAllInsumos() async {
    final db = await instance.database;
    final result = await db.query('insumos');
    return result.map((json) => Insumo.fromMap(json)).toList();
  }

  // --- Operaciones para APUs ---

  Future<void> insertApus(List<Apu> apus) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var apu in apus) {
      batch.insert('apus', apu.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (var item in apu.items) {
        batch.insert('apu_items', item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<Apu>> getAllApus() async {
    final db = await instance.database;
    final apuMaps = await db.query('apus');
    
    final itemMaps = await db.query('apu_items');
    final insumos = await getAllInsumos();
    final insumoMap = {for (var i in insumos) i.codigo: i};

    List<Apu> result = [];
    for (var apuMap in apuMaps) {
      final apuCodigo = apuMap['codigo'] as String;
      
      final apuItemsMaps = itemMaps.where((i) => i['apuCodigo'] == apuCodigo);
      final List<ApuItem> items = apuItemsMaps.map((map) {
        final insumo = insumoMap[map['insumoCodigo']];
        return ApuItem.fromMap(map, insumo: insumo);
      }).toList();

      result.add(Apu.fromMap(apuMap, items: items));
    }

    return result;
  }

  Future<List<Apu>> getApusByProject(int projectId) async {
    final db = await instance.database;
    final apuMaps = await db.query('apus', where: 'projectId = ?', whereArgs: [projectId]);
    
    final itemMaps = await db.query('apu_items');
    final insumos = await getAllInsumos();
    final insumoMap = {for (var i in insumos) i.codigo: i};

    List<Apu> result = [];
    for (var apuMap in apuMaps) {
      final apuCodigo = apuMap['codigo'] as String;
      
      final apuItemsMaps = itemMaps.where((i) => i['apuCodigo'] == apuCodigo);
      final List<ApuItem> items = apuItemsMaps.map((map) {
        final insumo = insumoMap[map['insumoCodigo']];
        return ApuItem.fromMap(map, insumo: insumo);
      }).toList();

      result.add(Apu.fromMap(apuMap, items: items));
    }

    return result;
  }

  // --- Operaciones de EVM (Progreso y Salidas) ---

  Future<void> insertInventoryIssue(Map<String, dynamic> issueMap) async {
    final db = await instance.database;
    await db.insert('inventory_issues', issueMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertFieldProgress(Map<String, dynamic> progressMap) async {
    final db = await instance.database;
    await db.insert('field_progress', progressMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getInventoryIssuesForApu(String apuCodigo) async {
    final db = await instance.database;
    return await db.query('inventory_issues', where: 'apuCodigo = ?', whereArgs: [apuCodigo]);
  }

  Future<List<Map<String, dynamic>>> getFieldProgressForApu(String apuCodigo) async {
    final db = await instance.database;
    return await db.query('field_progress', where: 'apuCodigo = ?', whereArgs: [apuCodigo]);
  }
}
