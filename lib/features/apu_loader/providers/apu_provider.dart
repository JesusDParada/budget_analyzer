import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:budget_analyzer/domain/models/apu.dart';
import 'package:budget_analyzer/data/repositories/excel_apu_repository.dart';

final apuRepositoryProvider = Provider<ExcelApuRepository>((ref) {
  return ExcelApuRepository();
});

class ApuLoaderState {
  final bool isLoading;
  final String? error;
  final List<Apu> apusCargados;

  ApuLoaderState({
    this.isLoading = false,
    this.error,
    this.apusCargados = const [],
  });

  ApuLoaderState copyWith({
    bool? isLoading,
    String? error,
    List<Apu>? apusCargados,
  }) {
    return ApuLoaderState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      apusCargados: apusCargados ?? this.apusCargados,
    );
  }
}

class ApuLoaderNotifier extends Notifier<ApuLoaderState> {
  late final ExcelApuRepository _repository;

  @override
  ApuLoaderState build() {
    _repository = ref.watch(apuRepositoryProvider);
    Future.microtask(() => _init());
    return ApuLoaderState();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final apus = await _repository.getAllApus();
      state = state.copyWith(isLoading: false, apusCargados: apus);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> pickAndLoadExcel() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final extractionResult = await _repository.loadApusFromFile(path);

        state = state.copyWith(
          isLoading: false,
          apusCargados: extractionResult.apus,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar el archivo: \$e',
      );
    }
  }
}

final apuLoaderProvider = NotifierProvider<ApuLoaderNotifier, ApuLoaderState>(
  () {
    return ApuLoaderNotifier();
  },
);
