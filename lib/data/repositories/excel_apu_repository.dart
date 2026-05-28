import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:excel/excel.dart';
import 'package:budget_analyzer/domain/models/project.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';
import 'package:budget_analyzer/domain/repositories/i_apu_repository.dart';
import 'package:budget_analyzer/data/local_db/database_helper.dart';
import 'package:budget_analyzer/core/utils/xlsx_cached_value_reader.dart';

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
        bac: apu.bac,
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
    
    // Use the xlsx XML reader to get cached formula values
    final cachedReader = XlsxCachedValueReader(bytes);
    print('DEBUG: XlsxCachedValueReader tomó ${sw.elapsedMilliseconds} ms');

    sw.reset();
    // Also decode with the excel package for sheet serialization and structure
    var excel = Excel.decodeBytes(bytes);
    print('DEBUG: Excel.decodeBytes tomó ${sw.elapsedMilliseconds} ms');

    final presupuestoSheet = excel.tables['PRESUPUESTO DE OBRA'];
    if (presupuestoSheet == null) {
      throw Exception('No se encontró la hoja PRESUPUESTO DE OBRA en el archivo.');
    }

    List<Apu> apusList = [];
    final codePattern = RegExp(r'^\d+(\.\d+)+$'); // 1.1, 2.1, etc.

    int serializeTime = 0;

    for (int i = 0; i < presupuestoSheet.maxRows; i++) {
      var row = presupuestoSheet.row(i);
      if (row.length > 3) {
        var rawCode = row[1]?.value?.toString().trim() ?? '';
        if (codePattern.hasMatch(rawCode)) {
          final codigo = rawCode;

          // Excel row number is 1-based (row index i is Excel row i+1)
          final excelRow = i + 1;

          // Read cached values from the xlsx XML (these are the values
          // that Excel calculated and stored the last time the file was saved).
          // Column E = Vr. Unitario, Column F = Cantidad, Column G = Vr. Parcial (BAC)
          final nombre = cachedReader.getCachedString('PRESUPUESTO DE OBRA', 'C$excelRow') 
                         ?? row[2]?.value?.toString() ?? '';
          final unidad = cachedReader.getCachedString('PRESUPUESTO DE OBRA', 'D$excelRow') 
                         ?? row[3]?.value?.toString() ?? '';
          
          final valorUnitario = cachedReader.getCachedDouble('PRESUPUESTO DE OBRA', 'E$excelRow') ?? 0.0;
          final cantidad = cachedReader.getCachedDouble('PRESUPUESTO DE OBRA', 'F$excelRow') ?? 0.0;
          final bac = cachedReader.getCachedDouble('PRESUPUESTO DE OBRA', 'G$excelRow') ?? 0.0;

          print('DEBUG: APU $codigo - Vr.Unit=$valorUnitario, Cant=$cantidad, BAC=$bac');

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
            bac: bac,
            detalleJson: detalleJson,
            memoriaJson: memoriaJson,
            items: const [], // No requerimos poblar la lista para otras vistas
          ));
        }
      }
    }
    
    print('DEBUG: Serialización JSON tomó $serializeTime ms');
    print('DEBUG: Procesamiento de ${apusList.length} APUs tomó ${sw.elapsedMilliseconds} ms total');
    
    return apusList;
  }


  /// Maximum dimensions for serialized APU sheets.
  /// APU detail sheets (e.g. "1.1", "M-1.1") only contain meaningful data
  /// within the first ~50 rows and ~10 columns. The Excel file may contain
  /// stray values (e.g. "Código" at row 8177 or #REF! at column 136) that
  /// inflate the payload to >5 MB and crash the sqflite FFI isolate.
  static const int _maxSerializeRows = 200;
  static const int _maxSerializeCols = 20;

  /// Checks if a cell value is meaningful (not null, empty, or an error like #REF!).
  static bool _isMeaningfulCell(Data? cell) {
    if (cell?.value == null) return false;
    final str = cell!.value.toString().trim();
    if (str.isEmpty) return false;
    // Skip Excel error values that inflate the sheet dimensions
    if (str.startsWith('#') && (str.contains('REF') || str.contains('VALUE') || str.contains('NAME') || str.contains('NULL') || str.contains('N/A') || str.contains('DIV'))) {
      return false;
    }
    return true;
  }

  static String? _serializeSheet(Excel excel, String sheetName) {
    var sheet = excel.tables[sheetName];
    if (sheet == null) return null;

    // Cap rows to avoid scanning massive empty regions caused by stray cells
    final maxRowsToScan = sheet.maxRows < _maxSerializeRows ? sheet.maxRows : _maxSerializeRows;

    // Find the actual last row with meaningful data (within the capped range)
    int actualMaxRow = 0;
    for (int r = maxRowsToScan - 1; r >= 0; r--) {
      bool hasData = false;
      var row = sheet.row(r);
      for (int c = 0; c < row.length && c < _maxSerializeCols; c++) {
        if (_isMeaningfulCell(row[c])) {
          hasData = true;
          break;
        }
      }
      if (hasData) {
        actualMaxRow = r + 1;
        break;
      }
    }

    if (actualMaxRow == 0) return null; // Sheet has no meaningful data

    // Find the actual last column with meaningful data (within the capped range)
    int actualMaxCol = 0;
    for (int r = 0; r < actualMaxRow; r++) {
      var row = sheet.row(r);
      final colLimit = row.length < _maxSerializeCols ? row.length : _maxSerializeCols;
      for (int c = colLimit - 1; c >= 0; c--) {
        if (c < actualMaxCol) break; // Optimization: already found wider
        if (_isMeaningfulCell(row[c])) {
          if (c + 1 > actualMaxCol) {
            actualMaxCol = c + 1;
          }
          break;
        }
      }
    }

    if (actualMaxCol == 0) return null; // No meaningful columns

    List<List<dynamic>> rowsList = [];
    for (int r = 0; r < actualMaxRow; r++) {
      var row = sheet.row(r);
      List<dynamic> rowList = [];
      for (int c = 0; c < actualMaxCol; c++) {
        var cell = (c < row.length) ? row[c] : null;
        rowList.add(cell?.value?.toString());
      }
      rowsList.add(rowList);
    }
    return jsonEncode(rowsList);
  }
}
