import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';

abstract class IApuRepository {
  /// Carga y extrae la lista de APUs e Insumos desde un archivo de Excel
  Future<ApuExtractionResult> loadApusFromFile(String filePath);
  
  /// Obtiene todos los APUs guardados localmente
  Future<List<Apu>> getAllApus();
  
  /// Obtiene todos los insumos guardados localmente
  Future<List<Insumo>> getAllInsumos();
}

class ApuExtractionResult {
  final List<Apu> apus;
  final List<Insumo> insumos;

  ApuExtractionResult({required this.apus, required this.insumos});
}
