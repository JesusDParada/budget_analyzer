import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:excel/excel.dart';
import 'package:budget_analyzer/core/utils/formula_evaluator.dart';

void main() async {
  print('Iniciando lectura...');
  final sw = Stopwatch()..start();
  final bytes = await File('REVISABLE - ConstruIA - GENERADOR DE PRESUPUESTOS DE OBRA 2.08 prueba.xlsx').readAsBytes();
  
  // 1. Decode ZIP
  final archive = ZipDecoder().decodeBytes(bytes);
  
  // 2. Modify workbook.xml
  final workbookFile = archive.findFile('xl/workbook.xml');
  if (workbookFile == null) {
    print("No workbook.xml found!");
    return;
  }
  
  workbookFile.decompress();
  final document = XmlDocument.parse(String.fromCharCodes(workbookFile.content));
  final sheetsNode = document.findAllElements('sheets').first;
  final sheets = sheetsNode.findElements('sheet').toList();
  
  final sheetsToKeep = ['PRESUPUESTO DE OBRA', '1.1', 'M-1.1', '2.1', 'M-2.1']; 
  for (var sheet in sheets) {
    final name = sheet.getAttribute('name');
    if (!sheetsToKeep.contains(name)) {
      sheet.parent?.children.remove(sheet);
    }
  }
  
  final newContent = utf8.encode(document.toXmlString());
  
  // create a new archive
  final newArchive = Archive();
  for (var f in archive.files) {
    if (f.name == 'xl/workbook.xml') {
      newArchive.addFile(ArchiveFile('xl/workbook.xml', newContent.length, newContent));
    } else {
      newArchive.addFile(f);
    }
  }
  
  // 3. Re-encode ZIP
  final newZipBytes = ZipEncoder().encode(newArchive);
  print('Modificacion ZIP tomo: ${sw.elapsedMilliseconds}ms');
  
  sw.reset();
  var excel = Excel.decodeBytes(bytes);
  print('Excel decodeBytes tomo: ${sw.elapsedMilliseconds}ms');
  
  sw.reset();
  var evaluator = FormulaEvaluator(excel);
  final presupuestoSheet = excel.tables['PRESUPUESTO DE OBRA'];
  if (presupuestoSheet == null) {
    print('No se encontró PRESUPUESTO DE OBRA');
    return;
  }

  final codePattern = RegExp(r'^\d+(\.\d+)+$'); // 1.1, 2.1, etc.
  int extracted = 0;
  for (int i = 0; i < presupuestoSheet.maxRows; i++) {
    var row = presupuestoSheet.rows[i];
    if (row.length > 3) {
      var rawCode = row[1]?.value?.toString().trim() ?? '';
      if (codePattern.hasMatch(rawCode)) {
        double valorUnitario = 0.0;
        double cantidad = 0.0;

        if (row.length > 4 && row[4] != null) {
          valorUnitario = evaluator.evaluateValue('PRESUPUESTO DE OBRA', row[4]!.value!);
        }
        if (row.length > 5 && row[5] != null) {
          cantidad = evaluator.evaluateValue('PRESUPUESTO DE OBRA', row[5]!.value!);
        }
        extracted++;
      }
    }
  }
  print('Formula evaluacion tomo: ${sw.elapsedMilliseconds}ms. APUs=$extracted');
}
