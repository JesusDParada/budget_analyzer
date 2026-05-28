import 'dart:io';
import 'package:excel/excel.dart';
import 'dart:convert';

void main() async {
  final path = 'REVISABLE - ConstruIA - GENERADOR DE PRESUPUESTOS DE OBRA 2.08 prueba.xlsx';
  final bytes = await File(path).readAsBytes();
  var excel = Excel.decodeBytes(bytes);

  var sheet = excel.tables['1.1'];
  if (sheet == null) {
    print('No se encontro la hoja 1.1');
    return;
  }

  print('Sheet 1.1 maxRows: \${sheet.maxRows}, maxCols: \${sheet.maxColumns}');
  
  for (int r = 0; r < sheet.maxRows && r < 50; r++) {
    var row = sheet.row(r);
    List<String> rowValues = [];
    bool hasData = false;
    for (int c = 0; c < row.length && c < 15; c++) {
      var cell = row[c];
      var val = cell?.value?.toString().trim() ?? '';
      rowValues.add(val.isEmpty ? 'NULL' : val);
      if (val.isNotEmpty) hasData = true;
    }
    if (hasData) {
      print('Row $r: ${rowValues.join(" | ")}');
    }
  }
}
