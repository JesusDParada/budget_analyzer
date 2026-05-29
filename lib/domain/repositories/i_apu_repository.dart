import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';
import 'package:budget_analyzer/domain/models/capitulo.dart';

abstract class IApuRepository {
  /// Carga y extrae la lista de APUs e Insumos desde un archivo de Excel para un proyecto específico
  Future<ApuExtractionResult> loadApusFromFile(String filePath, String projectName);
  
  /// Obtiene todos los APUs guardados localmente
  Future<List<Apu>> getAllApus();

  /// Obtiene las APUs de un proyecto específico
  Future<List<Apu>> getApusByProject(int projectId);
  
  /// Obtiene todos los insumos guardados localmente
  Future<List<Insumo>> getAllInsumos();

  /// Obtiene los capítulos de un proyecto
  Future<List<Capitulo>> getCapitulosByProject(int projectId);
}

class ApuExtractionResult {
  final List<Capitulo> capitulos;
  final List<Apu> apus;
  final List<Insumo> insumos;

  ApuExtractionResult({required this.capitulos, required this.apus, required this.insumos});
}
