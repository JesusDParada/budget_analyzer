import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/project.dart';
import 'package:budget_analyzer/domain/models/capitulo.dart';

import 'package:budget_analyzer/core/providers/project_providers.dart';
import 'package:budget_analyzer/data/supabase/supabase_helper.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';
import 'package:budget_analyzer/data/repositories/supabase_apu_repository.dart';

final apuRepositoryProvider = Provider<SupabaseApuRepository>((ref) {
  return SupabaseApuRepository();
});

class ApuLoaderState {
  final bool isLoading;
  final String? error;
  final List<Capitulo> capitulosCargados;
  final List<Apu> apusCargados;

  ApuLoaderState({
    this.isLoading = false,
    this.error,
    this.capitulosCargados = const [],
    this.apusCargados = const [],
  });

  ApuLoaderState copyWith({
    bool? isLoading,
    String? error,
    List<Capitulo>? capitulosCargados,
    List<Apu>? apusCargados,
  }) {
    return ApuLoaderState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      capitulosCargados: capitulosCargados ?? this.capitulosCargados,
      apusCargados: apusCargados ?? this.apusCargados,
    );
  }
}

class ApuLoaderNotifier extends Notifier<ApuLoaderState> {
  late SupabaseApuRepository _repository;

  @override
  ApuLoaderState build() {
    _repository = ref.watch(apuRepositoryProvider);
    Future.microtask(() => _init());
    return ApuLoaderState();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final activeProject = ref.read(activeProjectProvider);
      
      List<Apu> apus = [];
      List<Capitulo> capitulos = [];
      
      if (activeProject != null) {
          apus = await _repository.getApusByProject(activeProject.id!);
          capitulos = await _repository.getCapitulosByProject(activeProject.id!);
      } else {
          apus = await _repository.getAllApus();
          capitulos = await SupabaseHelper.instance.getAllCapitulos();
      }
          
      state = state.copyWith(isLoading: false, apusCargados: apus, capitulosCargados: capitulos);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> pickAndLoadExcel(String projectName) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final extractionResult = await _repository.loadApusFromFile(path, projectName);

        // Invalidar lista de proyectos para que se vuelva a cargar
        ref.invalidate(projectListProvider);
        
        // Asignar el proyecto activo en la app
        if (extractionResult.projectId != null) {
          final projectId = extractionResult.projectId;
          final project = Project(
            id: projectId,
            name: projectName,
            date: DateTime.now().toIso8601String(),
          );
          ref.read(activeProjectProvider.notifier).selectProject(project);
        }

        state = state.copyWith(
          isLoading: false,
          capitulosCargados: extractionResult.capitulos,
          apusCargados: extractionResult.apus,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar el archivo: $e',
      );
    }
  }

  Future<void> createProject(String name) async {
    try {
      final project = Project(name: name, date: DateTime.now().toIso8601String());
      final createdProject = await _repository.createProject(project);
      
      ref.invalidate(projectListProvider);
      ref.read(activeProjectProvider.notifier).selectProject(createdProject);
      
      state = state.copyWith(capitulosCargados: [], apusCargados: []);
    } catch (e) {
      state = state.copyWith(error: 'Error al crear proyecto: $e');
    }
  }

  Future<void> createCapitulo(int projectId, int numero, String nombre) async {
    try {
      final capitulo = Capitulo(projectId: projectId, numero: numero, nombre: nombre);
      final createdCapitulo = await _repository.createCapitulo(capitulo);
      
      state = state.copyWith(
        capitulosCargados: [...state.capitulosCargados, createdCapitulo]..sort((a, b) => a.numero.compareTo(b.numero)),
      );
    } catch (e) {
      state = state.copyWith(error: 'Error al crear capítulo: $e');
    }
  }

  Future<void> createActivity(int capituloId, String codigo, String nombre, String unidad, double cantidad, double valorUnitario, double bac, List<Insumo> insumos) async {
    try {
      List<Insumo> finalInsumos = List.from(insumos);
      // Si no se proporcionaron insumos, creamos uno por defecto con el mismo nombre y valor unitario
      if (finalInsumos.isEmpty && valorUnitario > 0) {
        finalInsumos.add(
          Insumo(
            activityId: 0, // Se actualizará en DatabaseHelper
            descripcion: nombre,
            unidad: unidad,
            valorUnitario: valorUnitario,
            cantidad: 1.0, // 1 unidad del insumo por cada unidad de actividad
          )
        );
      }

      final apu = Apu(
        codigo: codigo,
        nombre: nombre,
        unidad: unidad,
        cantidad: cantidad,
        valorUnitario: valorUnitario,
        bac: bac,
        capituloId: capituloId,
        insumos: finalInsumos,
      );
      
      final createdApu = await _repository.createApu(apu);
      
      state = state.copyWith(
        apusCargados: [...state.apusCargados, createdApu],
      );
    } catch (e) {
      state = state.copyWith(error: 'Error al crear actividad: $e');
    }
  }
}

final apuLoaderProvider = NotifierProvider<ApuLoaderNotifier, ApuLoaderState>(
  () {
    return ApuLoaderNotifier();
  },
);
