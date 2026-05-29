import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/domain/repositories/i_evm_repository.dart';
import 'package:budget_analyzer/data/repositories/local_db_evm_repository_impl.dart';
import 'package:budget_analyzer/domain/models/evm_metrics.dart';
import 'package:budget_analyzer/core/providers/project_providers.dart';
import 'package:budget_analyzer/data/local_db/database_helper.dart';
import 'package:budget_analyzer/domain/models/capitulo.dart';

// Provider global para el repositorio
final evmRepositoryProvider = Provider<IEvmRepository>((ref) {
  return LocalDbEvmRepositoryImpl();
});

// Provider para la lista de APUs de forma reactiva al proyecto seleccionado
final apusListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(evmRepositoryProvider);
  final activeProject = ref.watch(activeProjectProvider);
  return repository.getApus(projectId: activeProject?.id);
});

// Provider para la lista de Capítulos
final capitulosListProvider = FutureProvider<List<Capitulo>>((ref) async {
  final activeProject = ref.watch(activeProjectProvider);
  if (activeProject == null) {
    return await DatabaseHelper.instance.getAllCapitulos();
  }
  return await DatabaseHelper.instance.getCapitulosByProject(activeProject.id!);
});

// Family Provider para las métricas de un APU específico
final apuMetricsProvider = FutureProvider.family<EvmMetrics, int>((ref, activityId) async {
  final repository = ref.watch(evmRepositoryProvider);
  return repository.calculateMetricsForApu(activityId);
});

// Provider para obtener insumos de una APU
final apuInsumosProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, activityId) async {
  final repository = ref.watch(evmRepositoryProvider);
  return repository.getApuInsumos(activityId);
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
final apuStockProvider = FutureProvider.family<Map<String, InsumoStock>, int>((ref, activityId) async {
  final repository = ref.watch(evmRepositoryProvider);
  final metrics = await repository.calculateMetricsForApu(activityId);
  
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

// --- Insumos Compartidos ---

class SharedInsumoActivity {
  final int activityId;
  final String activityCode;
  final String activityName;
  final double budgetQuantity;

  SharedInsumoActivity({
    required this.activityId,
    required this.activityCode,
    required this.activityName,
    required this.budgetQuantity,
  });
}

/// Detecta insumos que aparecen en múltiples actividades dentro del mismo capítulo.
final sharedInsumosProvider = FutureProvider<Map<String, List<SharedInsumoActivity>>>((ref) async {
  final apus = await ref.watch(apusListProvider.future);
  final repository = ref.watch(evmRepositoryProvider);

  // Agrupar APUs por capítulo
  Map<int, List<Map<String, dynamic>>> byChapter = {};
  for (var apu in apus) {
    final capId = apu['capituloId'] as int?;
    if (capId != null) {
      byChapter.putIfAbsent(capId, () => []).add(apu);
    }
  }

  Map<String, List<SharedInsumoActivity>> result = {};

  for (var entry in byChapter.entries) {
    Map<String, List<SharedInsumoActivity>> chapterInsumos = {};

    for (var apu in entry.value) {
      final activityId = apu['id'] as int;
      final insumos = await repository.getApuInsumos(activityId);

      for (var insumo in insumos) {
        final desc = insumo['descripcion'] as String;
        final qty = (insumo['cantidad'] as num?)?.toDouble() ?? 0.0;
        chapterInsumos.putIfAbsent(desc, () => []).add(
          SharedInsumoActivity(
            activityId: activityId,
            activityCode: apu['code'] as String,
            activityName: apu['description'] as String,
            budgetQuantity: qty,
          ),
        );
      }
    }

    // Solo conservar insumos que aparecen en 2+ actividades
    for (var e in chapterInsumos.entries) {
      if (e.value.length > 1) {
        result[e.key] = e.value;
      }
    }
  }

  return result;
});

/// Stock compartido para un insumo — agrega compras/consumos de todas las
/// actividades que lo comparten, en orden cronológico con FIFO.
final sharedStockProvider = FutureProvider.family<InsumoStock, String>((ref, insumoDesc) async {
  final sharedMap = await ref.watch(sharedInsumosProvider.future);
  final activities = sharedMap[insumoDesc];
  if (activities == null || activities.isEmpty) return InsumoStock(0, [], null);

  final repository = ref.watch(evmRepositoryProvider);

  // Recopilar registros en orden cronológico desde TODAS las actividades
  List<(DateTime, double, double, double)> allRecords = [];

  for (var act in activities) {
    final metrics = await repository.calculateMetricsForApu(act.activityId);
    for (var cut in metrics.evRecords) {
      final cutDate = DateTime.tryParse(cut['date']?.toString() ?? '') ?? DateTime.now();
      final purchases = cut['purchases'] as List<dynamic>? ?? [];
      for (var p in purchases) {
        final desc = p['insumoDescription'] as String;
        if (desc != insumoDesc) continue;
        allRecords.add((
          cutDate,
          (p['purchasedQuantity'] as num).toDouble(),
          (p['consumedQuantity'] as num).toDouble(),
          (p['realPrice'] as num).toDouble(),
        ));
      }
    }
  }

  allRecords.sort((a, b) => a.$1.compareTo(b.$1));

  List<StockBatch> batches = [];
  double? lastPrice;

  for (var record in allRecords) {
    final purchased = record.$2;
    var consumed = record.$3;
    final price = record.$4;

    if (purchased > 0) {
      batches.add(StockBatch(purchased, price));
      lastPrice = price;
    } else if (purchased == 0 && consumed > 0 && price > 0) {
      lastPrice = price;
    }

    if (consumed > 0) {
      for (var batch in batches) {
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

  final activeBatches = batches.where((b) => b.remainingQty > 0).toList();
  final totalQty = activeBatches.fold<double>(0.0, (sum, b) => sum + b.remainingQty);
  return InsumoStock(totalQty, activeBatches, lastPrice);
});

// Notifier para el borrador de compras por APU en el corte actual
class DraftPurchasesNotifier extends Notifier<Map<int, List<Map<String, dynamic>>>> {
  @override
  Map<int, List<Map<String, dynamic>>> build() {
    return {};
  }

  void addPurchase(
      int activityId, 
      String insumoDesc, 
      double newPrice, 
      double purchasedQuantity, 
      double consumedQuantity,
      InsumoStock? currentStock) {
        
    final currentList = state[activityId] ?? [];
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
      activityId: newList,
    };
  }

  /// Agrega una compra de un insumo compartido, distribuyendo el consumo
  /// porcentualmente entre las actividades que lo comparten.
  /// La compra (purchasedQuantity) se asigna solo a la actividad origen.
  void addSharedPurchase(
    int originActivityId,
    String insumoDesc,
    double newPrice,
    double purchasedQuantity,
    double totalConsumedQuantity,
    InsumoStock? currentSharedStock,
    Map<int, double> allocationFractions,
  ) {
    // Paso 1: Calcular consumo FIFO desde stock existente
    List<({double price, double consumed})> fifoRecords = [];
    double remainingToConsume = totalConsumedQuantity;

    if (currentSharedStock != null && currentSharedStock.batches.isNotEmpty) {
      List<StockBatch> tempBatches = currentSharedStock.batches
          .map((b) => StockBatch(b.remainingQty, b.price))
          .toList();

      for (var batch in tempBatches) {
        if (remainingToConsume <= 0) break;
        if (batch.remainingQty > 0) {
          double consumedFromBatch;
          if (batch.remainingQty >= remainingToConsume) {
            consumedFromBatch = remainingToConsume;
            remainingToConsume = 0;
          } else {
            consumedFromBatch = batch.remainingQty;
            remainingToConsume -= batch.remainingQty;
          }
          fifoRecords.add((price: batch.price, consumed: consumedFromBatch));
        }
      }
    }

    // Paso 2: Consumo restante del nuevo lote
    if (remainingToConsume > 0) {
      fifoRecords.add((price: newPrice, consumed: remainingToConsume));
    }

    // Paso 3: Distribuir entre actividades
    Map<int, List<Map<String, dynamic>>> newState = {
      for (var entry in state.entries) entry.key: List.from(entry.value),
    };

    for (var entry in allocationFractions.entries) {
      final actId = entry.key;
      final pct = entry.value;

      final newList = List<Map<String, dynamic>>.from(newState[actId] ?? []);

      for (var fifo in fifoRecords) {
        final consumedPortion = fifo.consumed * pct;
        if (consumedPortion > 0) {
          newList.add({
            'insumoDescription': insumoDesc,
            'realPrice': fifo.price,
            'purchasedQuantity': 0.0,
            'consumedQuantity': consumedPortion,
          });
        }
      }

      // Registro de compra solo para la actividad origen
      if (actId == originActivityId && purchasedQuantity > 0) {
        newList.add({
          'insumoDescription': insumoDesc,
          'realPrice': newPrice,
          'purchasedQuantity': purchasedQuantity,
          'consumedQuantity': 0.0,
        });
      }

      newState[actId] = newList;
    }

    state = newState;
  }

  void removePurchase(int activityId, int index) {
    final currentList = state[activityId] ?? [];
    if (index >= 0 && index < currentList.length) {
      final newList = List<Map<String, dynamic>>.from(currentList);
      newList.removeAt(index);
      state = {
        ...state,
        activityId: newList,
      };
    }
  }

  void clearPurchases(int activityId) {
    final newState = Map<int, List<Map<String, dynamic>>>.from(state);
    newState.remove(activityId);
    state = newState;
  }
}

final draftPurchasesProvider = NotifierProvider<DraftPurchasesNotifier, Map<int, List<Map<String, dynamic>>>>(() {
  return DraftPurchasesNotifier();
});
