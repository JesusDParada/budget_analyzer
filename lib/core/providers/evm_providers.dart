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

// Provider para obtener insumos de una APU
final apuInsumosProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, apuId) async {
  final repository = ref.watch(evmRepositoryProvider);
  return repository.getApuInsumos(apuId);
});

// Notifier para el borrador de compras por APU en el corte actual
class DraftPurchasesNotifier extends Notifier<Map<String, List<Map<String, dynamic>>>> {
  @override
  Map<String, List<Map<String, dynamic>>> build() {
    return {};
  }

  void addPurchase(String apuId, String insumoDesc, double realPrice, double purchasedQuantity) {
    final currentList = state[apuId] ?? [];
    final newList = List<Map<String, dynamic>>.from(currentList);
    newList.add({
      'insumoDescription': insumoDesc,
      'realPrice': realPrice,
      'purchasedQuantity': purchasedQuantity,
    });
    
    state = {
      ...state,
      apuId: newList,
    };
  }

  void removePurchase(String apuId, int index) {
    final currentList = state[apuId] ?? [];
    if (index >= 0 && index < currentList.length) {
      final newList = List<Map<String, dynamic>>.from(currentList);
      newList.removeAt(index);
      state = {
        ...state,
        apuId: newList,
      };
    }
  }

  void clearPurchases(String apuId) {
    final newState = Map<String, List<Map<String, dynamic>>>.from(state);
    newState.remove(apuId);
    state = newState;
  }
}

final draftPurchasesProvider = NotifierProvider<DraftPurchasesNotifier, Map<String, List<Map<String, dynamic>>>>(() {
  return DraftPurchasesNotifier();
});
