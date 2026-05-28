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

class StockBatch {
  double remainingQty;
  final double price;
  StockBatch(this.remainingQty, this.price);
}

class InsumoStock {
  final double totalQuantity;
  final List<StockBatch> batches;
  final double? lastPrice;
  InsumoStock(this.totalQuantity, this.batches, this.lastPrice);
}

// Provider para calcular el stock sobrante por insumo para una APU
final apuStockProvider = FutureProvider.family<Map<String, InsumoStock>, String>((ref, apuId) async {
  final repository = ref.watch(evmRepositoryProvider);
  final metrics = await repository.calculateMetricsForApu(apuId);
  
  Map<String, List<StockBatch>> batchesMap = {};
  Map<String, double> lastPriceMap = {};
  
  for (var cut in metrics.evRecords) {
    final purchases = cut['purchases'] as List<dynamic>? ?? [];
    for (var p in purchases) {
      final desc = p['insumoDescription'] as String;
      final purchased = (p['purchasedQuantity'] as num).toDouble();
      var consumed = (p['consumedQuantity'] as num).toDouble();
      final price = (p['realPrice'] as num).toDouble();
      
      batchesMap.putIfAbsent(desc, () => []);
      
      if (purchased > 0) {
        batchesMap[desc]!.add(StockBatch(purchased, price));
        lastPriceMap[desc] = price;
      } else if (purchased == 0 && consumed > 0) {
        // En caso de que se haya consumido algo viejo o se haya ingresado un consumo no autorizado, actualizamos el lastPrice si es que es distinto de 0
        if (price > 0) lastPriceMap[desc] = price;
      }
      
      if (consumed > 0) {
        // FIFO deduction
        for (var batch in batchesMap[desc]!) {
          if (consumed <= 0) break;
          if (batch.remainingQty > 0) {
             if (batch.remainingQty >= consumed) {
               batch.remainingQty -= consumed;
               consumed = 0;
             } else {
               consumed -= batch.remainingQty;
               batch.remainingQty = 0;
             }
          }
        }
      }
    }
  }
  
  Map<String, InsumoStock> stock = {};
  for (var entry in batchesMap.entries) {
    final activeBatches = entry.value.where((b) => b.remainingQty > 0).toList();
    final totalQty = activeBatches.fold<double>(0.0, (sum, b) => sum + b.remainingQty);
    stock[entry.key] = InsumoStock(totalQty, activeBatches, lastPriceMap[entry.key]);
  }
  
  return stock;
});

// Notifier para el borrador de compras por APU en el corte actual
class DraftPurchasesNotifier extends Notifier<Map<String, List<Map<String, dynamic>>>> {
  @override
  Map<String, List<Map<String, dynamic>>> build() {
    return {};
  }

  void addPurchase(
      String apuId, 
      String insumoDesc, 
      double newPrice, 
      double purchasedQuantity, 
      double consumedQuantity,
      InsumoStock? currentStock) {
        
    final currentList = state[apuId] ?? [];
    final newList = List<Map<String, dynamic>>.from(currentList);
    
    double remainingToConsume = consumedQuantity;
    
    // 1. Consume from old stock first using FIFO
    if (currentStock != null && currentStock.batches.isNotEmpty) {
      List<StockBatch> tempBatches = currentStock.batches.map((b) => StockBatch(b.remainingQty, b.price)).toList();
      
      for (var batch in tempBatches) {
        if (remainingToConsume <= 0) break;
        if (batch.remainingQty > 0) {
          double consumedFromBatch = 0;
          if (batch.remainingQty >= remainingToConsume) {
            consumedFromBatch = remainingToConsume;
            batch.remainingQty -= remainingToConsume;
            remainingToConsume = 0;
          } else {
            consumedFromBatch = batch.remainingQty;
            remainingToConsume -= batch.remainingQty;
            batch.remainingQty = 0;
          }
          
          if (consumedFromBatch > 0) {
            newList.add({
              'insumoDescription': insumoDesc,
              'realPrice': batch.price, // Precio FIFO antiguo
              'purchasedQuantity': 0.0,
              'consumedQuantity': consumedFromBatch,
            });
          }
        }
      }
    }
    
    // 2. What is left to consume (either from new purchase or unauthorized)
    if (purchasedQuantity > 0 || remainingToConsume > 0) {
      newList.add({
        'insumoDescription': insumoDesc,
        'realPrice': newPrice,
        'purchasedQuantity': purchasedQuantity,
        'consumedQuantity': remainingToConsume,
      });
    }
    
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
