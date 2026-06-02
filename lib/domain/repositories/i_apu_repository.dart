import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';
import 'package:budget_analyzer/domain/models/capitulo.dart';
import 'package:budget_analyzer/domain/models/project.dart';

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

  /// Crea un nuevo proyecto manualmente
  Future<Project> createProject(Project project);

  /// Crea un nuevo capítulo manualmente
  Future<Capitulo> createCapitulo(Capitulo capitulo);

  /// Crea una nueva APU manualmente (con sus insumos)
  Future<Apu> createApu(Apu apu);
}

class ApuExtractionResult {
  final List<Capitulo> capitulos;
  final List<Apu> apus;
  final List<Insumo> insumos;
  final int? projectId;

  ApuExtractionResult({
    required this.capitulos,
    required this.apus,
    required this.insumos,
    this.projectId,
  });
}
