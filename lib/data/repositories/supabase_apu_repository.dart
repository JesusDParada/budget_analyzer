import 'dart:io';
import 'dart:isolate';
import 'package:budget_analyzer/domain/models/project.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';
import 'package:budget_analyzer/domain/models/capitulo.dart';
import 'package:budget_analyzer/domain/repositories/i_apu_repository.dart';
import 'package:budget_analyzer/data/supabase/supabase_helper.dart';
import 'package:budget_analyzer/data/repositories/excel_apu_repository.dart';

class SupabaseApuRepository implements IApuRepository {
  final SupabaseHelper _dbHelper = SupabaseHelper.instance;

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
    final bytes = await File(filePath).readAsBytes();

    // Use the static method from the old Excel repository for the actual parsing logic
    final extractionResult = await Isolate.run(() => ExcelApuRepository.extractApusFromBytes(bytes));

    final projectId = await _dbHelper.insertProject(
      Project(
        name: projectName,
        date: DateTime.now().toIso8601String(),
      ),
    );

    final capitulosToSave = extractionResult.capitulos.map((cap) {
      return Capitulo(
        numero: cap.numero,
        nombre: cap.nombre,
        projectId: projectId,
      );
    }).toList();
    
    final savedCapitulos = await _dbHelper.insertCapitulos(capitulosToSave);
    final capIdMap = { for (var cap in savedCapitulos) cap.numero: cap.id };

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

    await _dbHelper.insertApus(apusWithProject);

    return ApuExtractionResult(
      capitulos: savedCapitulos,
      apus: apusWithProject,
      insumos: const [],
      projectId: projectId,
    );
  }
}
