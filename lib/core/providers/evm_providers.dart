import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/domain/repositories/i_evm_repository.dart';
import 'package:budget_analyzer/data/repositories/mock_evm_repository_impl.dart';
import 'package:budget_analyzer/domain/models/evm_metrics.dart';

// Provider global para el repositorio
// Facilita la inyección de dependencias y el cambio a la base real después
final evmRepositoryProvider = Provider<IEvmRepository>((ref) {
  return MockEvmRepositoryImpl();
});

// Provider para la lista de APUs
final apuListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(evmRepositoryProvider);
  return repository.getApus();
});

// Family Provider para las métricas de un APU específico
final apuMetricsProvider = FutureProvider.family<EvmMetrics, String>((ref, apuId) async {
  final repository = ref.watch(evmRepositoryProvider);
  return repository.calculateMetricsForApu(apuId);
});
