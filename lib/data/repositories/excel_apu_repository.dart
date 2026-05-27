import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:excel/excel.dart';
import 'package:budget_analyzer/domain/models/project.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';
import 'package:budget_analyzer/domain/repositories/i_apu_repository.dart';
import 'package:budget_analyzer/data/local_db/database_helper.dart';
import 'package:budget_analyzer/core/utils/formula_evaluator.dart';

class ExcelApuRepository implements IApuRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Apu>> getAllApus() async {
    return await _dbHelper.getAllApus();
  }

  @override
  Future<List<Apu>> getApusByProject(int projectId) async {
    return await _dbHelper.getApusByProject(projectId);
  }

  @override
  Future<List<Insumo>> getAllInsumos() async {
    return await _dbHelper.getAllInsumos();
  }

  @override
  Future<ApuExtractionResult> loadApusFromFile(String filePath, String projectName) async {
    // 1. Leer el archivo en bytes
    final bytes = await File(filePath).readAsBytes();

    // 2. Extraer APUs en un Isolate para no bloquear el hilo principal (UI freeze)
    final apusList = await Isolate.run(() => extractApusFromBytes(bytes));

    // 3. Guardar Proyecto en la BD
    final projectId = await _dbHelper.insertProject(
      Project(
        name: projectName,
        date: DateTime.now().toIso8601String(),
      ),
    );

    // Asociar projectId a todas las APUs extraídas
    final apusWithProject = apusList.map((apu) {
      return Apu(
        codigo: apu.codigo,
        nombre: apu.nombre,
        unidad: apu.unidad,
        projectId: projectId,
        cantidad: apu.cantidad,
        valorUnitario: apu.valorUnitario,
        memoriaJson: apu.memoriaJson,
        detalleJson: apu.detalleJson,
        items: apu.items,
      );
    }).toList();

    // 4. Guardar en Base de Datos Local
    await _dbHelper.insertInsumos(const []);
    await _dbHelper.insertApus(apusWithProject);

    return ApuExtractionResult(apus: apusWithProject, insumos: const []);
  }

  static List<Apu> extractApusFromBytes(List<int> bytes) {
    final sw = Stopwatch()..start();
    var excel = Excel.decodeBytes(bytes);
    print('DEBUG: Excel.decodeBytes tomó ${sw.elapsedMilliseconds} ms');
    
    sw.reset();
    var evaluator = FormulaEvaluator(excel);

    final presupuestoSheet = excel.tables['PRESUPUESTO DE OBRA'];
    if (presupuestoSheet == null) {
      throw Exception('No se encontró la hoja PRESUPUESTO DE OBRA en el archivo.');
    }

    List<Apu> apusList = [];
    final codePattern = RegExp(r'^\d+(\.\d+)+$'); // 1.1, 2.1, etc.

    int serializeTime = 0;
    int evalTime = 0;

    for (int i = 0; i < presupuestoSheet.maxRows; i++) {
      var row = presupuestoSheet.row(i);
      if (row.length > 3) {
        var rawCode = row[1]?.value?.toString().trim() ?? '';
        if (codePattern.hasMatch(rawCode)) {
          final codigo = rawCode;
          final nombre = row[2]?.value?.toString() ?? '';
          final unidad = row[3]?.value?.toString() ?? '';

          double valorUnitario = 0.0;
          double cantidad = 0.0;

          final evalSw = Stopwatch()..start();
          if (row.length > 4 && row[4] != null) {
            valorUnitario = evaluator.evaluateValue('PRESUPUESTO DE OBRA', row[4]!.value!);
          }
          if (row.length > 5 && row[5] != null) {
            cantidad = evaluator.evaluateValue('PRESUPUESTO DE OBRA', row[5]!.value!);
          }
          evalTime += evalSw.elapsedMilliseconds;

          final serSw = Stopwatch()..start();
          // Serializar hoja de detalle (ej. "1.1")
          String? detalleJson = _serializeSheet(excel, codigo);

          // Serializar hoja de memoria (ej. "M-1.1")
          String? memoriaJson = _serializeSheet(excel, 'M-$codigo');
          serializeTime += serSw.elapsedMilliseconds;

          apusList.add(Apu(
            codigo: codigo,
            nombre: nombre,
            unidad: unidad,
            cantidad: cantidad,
            valorUnitario: valorUnitario,
            detalleJson: detalleJson,
            memoriaJson: memoriaJson,
            items: const [], // No requerimos poblar la lista para otras vistas
          ));
        }
      }
    }
    
    print('DEBUG: FormulaEvaluator tomó $evalTime ms');
    print('DEBUG: Serialización JSON tomó $serializeTime ms');
    print('DEBUG: Procesamiento de ${apusList.length} APUs tomó ${sw.elapsedMilliseconds} ms total');
    
    return apusList;
  }

  static String? _serializeSheet(Excel excel, String sheetName) {
    var sheet = excel.tables[sheetName];
    if (sheet == null) return null;
    
    // Find the actual max row that contains data to avoid iterating over empty formatted rows
    int actualMaxRow = 0;
    for (int r = sheet.maxRows - 1; r >= 0; r--) {
      bool hasData = false;
      for (var cell in sheet.row(r)) {
        if (cell?.value != null && cell!.value.toString().trim().isNotEmpty) {
          hasData = true;
          break;
        }
      }
      if (hasData) {
        actualMaxRow = r + 1;
        break;
      }
    }

    List<List<dynamic>> rowsList = [];
    for (int r = 0; r < actualMaxRow; r++) {
      var row = sheet.row(r);
      List<dynamic> rowList = [];
      for (int c = 0; c < row.length; c++) {
        var cell = row[c];
        rowList.add(cell?.value?.toString());
      }
      rowsList.add(rowList);
    }
    return jsonEncode(rowsList);
  }
}
