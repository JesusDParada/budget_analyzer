import 'dart:io';
import 'package:budget_analyzer/data/repositories/excel_apu_repository.dart';

void main() async {
  print('Iniciando extracción de APUs...');
  final bytes = await File('REVISABLE - ConstruIA - GENERADOR DE PRESUPUESTOS DE OBRA 2.08 prueba.xlsx').readAsBytes();
  final apus = ExcelApuRepository.extractApusFromBytes(bytes);
  print('Extracción completada. Encontradas \${apus.length} APUs.');
}
