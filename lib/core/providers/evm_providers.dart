import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/domain/repositories/i_evm_repository.dart';
import 'package:budget_analyzer/data/repositories/local_db_evm_repository_impl.dart';
import 'package:budget_analyzer/domain/models/evm_metrics.dart';
import 'package:budget_analyzer/core/providers/project_providers.dart';

// Provider global para el repositorio
final evmRepositoryProvider = Provider<IEvmRepository>((ref) {
  return LocalDbEvmRepositoryImpl();
});

// Provider para la lista de APUs de forma reactiva al proyecto seleccionado
final apuListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(evmRepositoryProvider);
  final activeProject = ref.watch(activeProjectProvider);
  return repository.getApus(projectId: activeProject?.id);
});

// Family Provider para las métricas de un APU específico
final apuMetricsProvider = FutureProvider.family<EvmMetrics, String>((ref, apuId) async {
  final repository = ref.watch(evmRepositoryProvider);
  return repository.calculateMetricsForApu(apuId);
});
