import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:budget_analyzer/domain/models/project.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';
import 'package:budget_analyzer/domain/models/capitulo.dart';
import 'package:budget_analyzer/domain/repositories/i_apu_repository.dart';
import 'package:budget_analyzer/data/local_db/database_helper.dart';
import 'package:budget_analyzer/core/utils/xlsx_cached_value_reader.dart';
import 'package:budget_analyzer/core/utils/apu_insumos_parser.dart';

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
  Future<List<Capitulo>> getCapitulosByProject(int projectId) async {
    return await _dbHelper.getCapitulosByProject(projectId);
  }

  @override
  Future<Project> createProject(Project project) async {
    final id = await _dbHelper.insertProject(project);
    return Project(id: id, name: project.name, date: project.date);
  }

  @override
  Future<Capitulo> createCapitulo(Capitulo capitulo) async {
    final id = await _dbHelper.insertCapitulo(capitulo);
    return Capitulo(
      id: id, 
      projectId: capitulo.projectId, 
      numero: capitulo.numero, 
      nombre: capitulo.nombre,
    );
  }

  @override
  Future<Apu> createApu(Apu apu) async {
    final id = await _dbHelper.insertApu(apu);
    return Apu(
      id: id,
      codigo: apu.codigo,
      nombre: apu.nombre,
      unidad: apu.unidad,
      cantidad: apu.cantidad,
      valorUnitario: apu.valorUnitario,
      bac: apu.bac,
      capituloId: apu.capituloId,
      insumos: apu.insumos,
    );
  }

  @override
  Future<ApuExtractionResult> loadApusFromFile(String filePath, String projectName) async {
    // 1. Leer el archivo en bytes
    final bytes = await File(filePath).readAsBytes();

    // 2. Extraer APUs en un Isolate para no bloquear el hilo principal (UI freeze)
    final extractionResult = await Isolate.run(() => extractApusFromBytes(bytes));

    // 3. Guardar Proyecto en la BD
    final projectId = await _dbHelper.insertProject(
      Project(
        name: projectName,
        date: DateTime.now().toIso8601String(),
      ),
    );

    // Guardar capítulos en BD y recuperar sus IDs
    final capitulosToSave = extractionResult.capitulos.map((cap) {
      return Capitulo(
        numero: cap.numero,
        nombre: cap.nombre,
        projectId: projectId,
      );
    }).toList();
    
    final savedCapitulos = await _dbHelper.insertCapitulos(capitulosToSave);

    // Create a map to find capituloId by chapter number
    final capIdMap = { for (var cap in savedCapitulos) cap.numero: cap.id };

    // Asociar capituloId a todas las APUs extraídas
    final apusWithProject = extractionResult.apus.map((apu) {
      return Apu(
        codigo: apu.codigo,
        nombre: apu.nombre,
        unidad: apu.unidad,
        capituloId: apu.capituloId != null ? capIdMap[apu.capituloId] : null,
        cantidad: apu.cantidad,
        valorUnitario: apu.valorUnitario,
        bac: apu.bac,
        memoriaJson: apu.memoriaJson,
        detalleJson: apu.detalleJson,
        insumos: apu.insumos,
      );
    }).toList();

    // 4. Guardar en Base de Datos Local
    await _dbHelper.insertApus(apusWithProject);

    return ApuExtractionResult(
      capitulos: savedCapitulos,
      apus: apusWithProject,
      insumos: const [],
      projectId: projectId,
    );
  }

  static ApuExtractionResult extractApusFromBytes(List<int> bytes) {
    final sw = Stopwatch()..start();
    
    // Use the xlsx XML reader to get cached formula values
    final cachedReader = XlsxCachedValueReader(bytes);
    debugPrint('DEBUG: XlsxCachedValueReader tomó ${sw.elapsedMilliseconds} ms');

    sw.reset();
    // Also decode with the excel package for sheet serialization and structure
    var excel = Excel.decodeBytes(bytes);
    debugPrint('DEBUG: Excel.decodeBytes tomó ${sw.elapsedMilliseconds} ms');

    final presupuestoSheet = excel.tables['PRESUPUESTO DE OBRA'];
    if (presupuestoSheet == null) {
      throw Exception('No se encontró la hoja PRESUPUESTO DE OBRA en el archivo.');
    }

    List<Apu> apusList = [];
    List<Capitulo> capitulosList = [];
    final codePattern = RegExp(r'^\d+(\.\d+)+$'); // 1.1, 2.1, etc.
    final chapterPattern = RegExp(r'^(\d+)\.\s*(.+)$'); // 1. MAPOSTERIA

    int serializeTime = 0;
    int currentChapterNumber = 0;

    for (int i = 0; i < presupuestoSheet.maxRows; i++) {
      var row = presupuestoSheet.row(i);
      if (row.length > 2) {
        var rawCode = row[1]?.value?.toString().trim() ?? '';
        var colC = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
        
        final matchB = chapterPattern.firstMatch(rawCode);
        final matchC = chapterPattern.firstMatch(colC);
        final match = matchB ?? matchC;
        
        if (match != null && !codePattern.hasMatch(rawCode) && !codePattern.hasMatch(colC)) {
           currentChapterNumber = int.parse(match.group(1)!);
           capitulosList.add(Capitulo(
             projectId: 0, 
             numero: currentChapterNumber, 
             nombre: match.group(2)!.trim(),
           ));
           continue;
        }

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

          debugPrint('DEBUG: APU $codigo - Vr.Unit=$valorUnitario, Cant=$cantidad, BAC=$bac');

          final serSw = Stopwatch()..start();
          // Serializar hoja de detalle (ej. "1.1")
          String? detalleJson = _serializeSheet(excel, codigo, cachedReader);

          // Serializar hoja de memoria (ej. "M-1.1")
          String? memoriaJson = _serializeSheet(excel, 'M-$codigo', cachedReader);
          serializeTime += serSw.elapsedMilliseconds;

          List<Insumo> extractedInsumos = [];
          if (detalleJson != null) {
            final parsedInsumos = ApuInsumosParser.parse(detalleJson);
            extractedInsumos = parsedInsumos.map((i) => Insumo(
              activityId: 0, // Will be assigned automatically by DatabaseHelper
              descripcion: i.descripcion,
              unidad: i.unidad,
              valorUnitario: i.precioUnitario,
              cantidad: i.cantidad,
            )).toList();
          }

          apusList.add(Apu(
            codigo: codigo,
            nombre: nombre,
            unidad: unidad,
            cantidad: cantidad,
            valorUnitario: valorUnitario,
            bac: bac,
            capituloId: currentChapterNumber > 0 ? currentChapterNumber : null,
            detalleJson: detalleJson,
            memoriaJson: memoriaJson,
            insumos: extractedInsumos,
          ));
        }
      }
    }
    
    debugPrint('DEBUG: Serialización JSON tomó $serializeTime ms');
    debugPrint('DEBUG: Procesamiento de ${apusList.length} APUs tomó ${sw.elapsedMilliseconds} ms total');
    
    return ApuExtractionResult(capitulos: capitulosList, apus: apusList, insumos: const []);
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

  static String _getCellRef(int row, int col) {
    String colStr = '';
    int c = col;
    while (c >= 0) {
      colStr = String.fromCharCode(65 + (c % 26)) + colStr;
      c = (c ~/ 26) - 1;
    }
    return '$colStr${row + 1}';
  }

  static String? _serializeSheet(Excel excel, String sheetName, XlsxCachedValueReader cachedReader) {
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
        if (cell != null) {
          String cellRef = _getCellRef(r, c);
          String? cachedStr = cachedReader.getCachedString(sheetName, cellRef);
          if (cachedStr != null && cachedStr.isNotEmpty) {
            rowList.add(cachedStr);
          } else {
            rowList.add(cell.value?.toString());
          }
        } else {
          rowList.add(null);
        }
      }
      rowsList.add(rowList);
    }
    return jsonEncode(rowsList);
  }
}
