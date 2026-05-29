import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/domain/models/project.dart';
import 'package:budget_analyzer/domain/models/capitulo.dart';
import 'package:budget_analyzer/data/repositories/excel_apu_repository.dart';
import 'package:budget_analyzer/core/providers/project_providers.dart';
import 'package:budget_analyzer/data/local_db/database_helper.dart';

final apuRepositoryProvider = Provider<ExcelApuRepository>((ref) {
  return ExcelApuRepository();
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
  late ExcelApuRepository _repository;

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
          capitulos = await DatabaseHelper.instance.getAllCapitulos();
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
        if (extractionResult.apus.isNotEmpty) {
          final projectId = extractionResult.apus.first.projectId;
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
}

final apuLoaderProvider = NotifierProvider<ApuLoaderNotifier, ApuLoaderState>(
  () {
    return ApuLoaderNotifier();
  },
);
