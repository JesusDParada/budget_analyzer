import 'package:budget_analyzer/domain/models/evm_metrics.dart';
import 'package:budget_analyzer/domain/repositories/i_evm_repository.dart';

/// Propósito Específico: Implementación Mock del repositorio de EVM para pruebas de UI y cálculos locales.
class MockEvmRepositoryImpl implements IEvmRepository {
  final List<Map<String, dynamic>> _apus = [
    {'id': 'apu-1', 'code': 'APU-001', 'description': 'Excavación manual', 'unit_measure': 'm3', 'total_quantity': 100.0, 'unit_price': 100.0, 'bac': 10000.0},
    {'id': 'apu-2', 'code': 'APU-002', 'description': 'Concreto 3000 PSI', 'unit_measure': 'm3', 'total_quantity': 50.0, 'unit_price': 300.0, 'bac': 15000.0},
  ];
  
  final List<Map<String, dynamic>> _cutRecords = [];
  final List<Map<String, dynamic>> _purchases = [];

  @override
  Future<EvmMetrics> calculateMetricsForApu(String apuId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final apuData = _apus.firstWhere((apu) => apu['id'] == apuId, orElse: () => throw Exception('APU no encontrado'));
    final double bac = apuData['bac'];
    final double totalQuantity = apuData['total_quantity'];

    double ac = 0.0;
    double executedQuantity = 0.0;
    List<Map<String, dynamic>> evRecords = [];

    final cuts = _cutRecords.where((c) => c['apu_id'] == apuId).toList();
    for (var cut in cuts) {
      final cutId = cut['id'];
      final actQty = cut['activityQuantity'];
      executedQuantity += actQty;
      
      final cutPurchases = _purchases.where((p) => p['cutRecordId'] == cutId).toList();
      double insumosCost = 0.0;
      for (var p in cutPurchases) {
        insumosCost += p['realPrice'] * p['consumedQuantity'];
      }
      final double cutAc = insumosCost;
      ac += cutAc;
      
      evRecords.add({
        'cutNumber': cut['cutNumber'],
        'date': cut['date'],
        'activityQuantity': actQty,
        'insumosCost': insumosCost,
        'cutAc': cutAc,
        'purchases': cutPurchases,
      });
    }

    final double ev = totalQuantity > 0 ? (executedQuantity / totalQuantity) * bac : 0.0;

    final double cpi = ac > 0 ? ev / ac : (ev > 0 ? double.infinity : 1.0); 
    final double eac = cpi > 0 && cpi != double.infinity ? bac / cpi : bac;
    final double etc = eac - ac;

    return EvmMetrics(
      apuId: apuId,
      ac: ac,
      ev: ev,
      cpi: cpi,
      eac: eac,
      bac: bac,
      etc: etc,
      evRecords: evRecords,
      acRecords: const [],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getApus({int? projectId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_apus);
  }

  @override
  Future<void> saveCutRecord(String apuId, double activityQuantity, DateTime date, List<Map<String, dynamic>> purchases) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final String cutId = DateTime.now().millisecondsSinceEpoch.toString();
    
    _cutRecords.add({
      'id': cutId,
      'apu_id': apuId,
      'cutNumber': _cutRecords.where((c) => c['apu_id'] == apuId).length + 1,
      'activityQuantity': activityQuantity,
      'date': date.toIso8601String(),
    });

    for (var p in purchases) {
      _purchases.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'cutRecordId': cutId,
        'insumoDescription': p['insumoDescription'],
        'realPrice': p['realPrice'],
        'purchasedQuantity': p['purchasedQuantity'],
        'consumedQuantity': p['consumedQuantity'],
      });
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getApuInsumos(String apuId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      {'codigo': 'I001', 'descripcion': 'Cemento', 'unidad': 'BTO', 'precioUnitario': 25000.0, 'cantidad': 10.0},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getCutRecordsForApu(String apuId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _cutRecords.where((c) => c['apu_id'] == apuId).toList();
  }
}
