import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';

abstract class IApuRepository {
  /// Carga y extrae la lista de APUs e Insumos desde un archivo de Excel para un proyecto específico
  Future<ApuExtractionResult> loadApusFromFile(String filePath, String projectName);
  
  /// Obtiene todos los APUs guardados localmente
  Future<List<Apu>> getAllApus();

  /// Obtiene las APUs de un proyecto específico
  Future<List<Apu>> getApusByProject(int projectId);
  
  /// Obtiene todos los insumos guardados localmente
  Future<List<Insumo>> getAllInsumos();
}

class ApuExtractionResult {
  final List<Apu> apus;
  final List<Insumo> insumos;

  ApuExtractionResult({required this.apus, required this.insumos});
}
