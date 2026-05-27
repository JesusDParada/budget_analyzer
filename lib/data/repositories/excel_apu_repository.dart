import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';
import 'package:budget_analyzer/domain/repositories/i_apu_repository.dart';
import 'package:budget_analyzer/data/local_db/database_helper.dart';

class ExcelApuRepository implements IApuRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Apu>> getAllApus() async {
    return await _dbHelper.getAllApus();
  }

  @override
  Future<List<Insumo>> getAllInsumos() async {
    return await _dbHelper.getAllInsumos();
  }

  @override
  Future<ApuExtractionResult> loadApusFromFile(String filePath) async {
    // 1. Ejecutar el parseo pesado en un isolate (hilo secundario) para no bloquear la UI
    final extractionResult = await compute(_parseExcelIsolate, filePath);

    // 2. Guardar en Base de Datos Local (DB helper maneja el asincronismo y lotes nativos)
    await _dbHelper.insertInsumos(extractionResult.insumos);
    await _dbHelper.insertApus(extractionResult.apus);

    return extractionResult;
  }

  // Función estática requerida para el Isolate
  static ApuExtractionResult _parseExcelIsolate(String filePath) {
    var bytes = File(filePath).readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);

    // Extraer Insumos
    final insumosSheet = excel.tables['INSUMOS'];
    if (insumosSheet == null) {
      throw Exception('No se encontró la hoja INSUMOS en el archivo.');
    }
    
    Map<String, Insumo> insumosMap = {};
    // La hoja INSUMOS tiene cabeceras en las primeras filas.
    // Iteramos e ignoramos las nulas. Basado en el log, los datos están aprox desde la fila 3
    for (int i = 3; i < insumosSheet.maxRows; i++) {
      var row = insumosSheet.rows[i];
      if (row.length > 5 && row[0]?.value != null && row[1]?.value != null) {
        final descripcion = row[0]?.value.toString() ?? '';
        final codigo = row[1]?.value.toString() ?? '';
        
        // Saltamos filas que son TIPO, GRUPO o CATEGORÍA si es que su precio es null, 
        // pero validamos que tengan código de insumo real (columna 11 es tipo)
        final tipo = row.length > 11 ? row[11]?.value?.toString() ?? 'INSUMO' : 'INSUMO';
        if (tipo != 'INSUMO') continue; // Solo insumos base tienen precio
        
        final unidad = row[2]?.value?.toString() ?? 'UND';
        
        double valorUnitario = 0;
        final val = row[3]?.value;
        if (val != null) {
          final strVal = val.toString();
          // Intentamos extraer cualquier número de la cadena por si es algo como IntCellValue(5)
          final regex = RegExp(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?');
          final match = regex.firstMatch(strVal);
          if (match != null) {
            valorUnitario = double.tryParse(match.group(0) ?? '0') ?? 0;
          }
        }
        
        final tipoClasif = row.length > 7 ? row[7]?.value?.toString() ?? 'A' : 'A'; // A, B, C...

        final insumo = Insumo(
          codigo: codigo,
          descripcion: descripcion,
          unidad: unidad,
          valorUnitario: valorUnitario,
          tipo: tipoClasif,
        );
        insumosMap[codigo] = insumo;
      }
    }

    // 2. Extraer APUs
    final apusSheet = excel.tables['DESGLOSE APUS'];
    if (apusSheet == null) {
      throw Exception('No se encontró la hoja DESGLOSE APUS en el archivo.');
    }

    Map<String, Apu> apusMap = {};
    
    // Ignoramos la cabecera (fila 0)
    for (int i = 1; i < apusSheet.maxRows; i++) {
      var row = apusSheet.rows[i];
      if (row.length > 8 && row[0]?.value != null && row[1]?.value != null) {
        final apuNombre = row[0]?.value.toString() ?? '';
        final apuCodigo = row[1]?.value.toString() ?? '';
        final apuUnidad = row[2]?.value.toString() ?? '';
        
        final insumoCodigo = row[5]?.value.toString() ?? '';
        double cantidad = 0;
        final qtyVal = row[8]?.value;
        if (qtyVal != null) {
          final strVal = qtyVal.toString();
          final regex = RegExp(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?');
          final match = regex.firstMatch(strVal);
          if (match != null) {
            cantidad = double.tryParse(match.group(0) ?? '0') ?? 0;
          }
        }

        // Recuperar insumo desde el maestro
        final insumoRef = insumosMap[insumoCodigo];

        final item = ApuItem(
          apuCodigo: apuCodigo,
          insumoCodigo: insumoCodigo,
          cantidad: cantidad,
          insumo: insumoRef,
        );

        if (!apusMap.containsKey(apuCodigo)) {
          apusMap[apuCodigo] = Apu(
            codigo: apuCodigo,
            nombre: apuNombre,
            unidad: apuUnidad,
            items: [],
          );
        }
        
        apusMap[apuCodigo]?.items.add(item);
      }
    }

    final resultApus = apusMap.values.toList();
    final resultInsumos = insumosMap.values.toList();
    
    return ApuExtractionResult(apus: resultApus, insumos: resultInsumos);
  }
}
