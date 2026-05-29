import 'package:budget_analyzer/domain/models/evm_metrics.dart';
import 'package:budget_analyzer/domain/repositories/i_evm_repository.dart';

/// Propósito Específico: Implementación Mock del repositorio de EVM para pruebas de UI y cálculos locales.
class MockEvmRepositoryImpl implements IEvmRepository {
  final List<Map<String, dynamic>> _apus = [
    {'id': 'apu-1', 'code': 'APU-001', 'description': 'Excavación manual', 'unit_measure': 'm3', 'total_quantity': 100.0, 'unit_price': 100.0, 'bac': 10000.0},
    {'id': 'apu-2', 'code': 'APU-002', 'description': 'Concreto 3000 PSI', 'unit_measure': 'm3', 'total_quantity': 50.0, 'unit_price': 300.0, 'bac': 15000.0},
    {'id': 1, 'code': 'APU-001', 'description': 'Excavación manual', 'unit_measure': 'm3', 'total_quantity': 100.0, 'unit_price': 100.0, 'bac': 10000.0},
    {'id': 2, 'code': 'APU-002', 'description': 'Concreto 3000 PSI', 'unit_measure': 'm3', 'total_quantity': 50.0, 'unit_price': 300.0, 'bac': 15000.0},
  ];
  
  final List<Map<String, dynamic>> _cutRecords = [];

  @override
  Future<EvmMetrics> calculateMetricsForApu(int activityId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final apuData = _apus.firstWhere((apu) => apu['id'] == activityId, orElse: () => throw Exception('Activity no encontrada'));
    
    final double bac = apuData['bac'];
    final double totalQty = apuData['total_quantity'];

    // Filtrar cortes
    final cuts = _cutRecords.where((c) => c['apu_id'] == activityId).toList();
    
    double ac = 0;
    double executedQty = 0;

    for (var cut in cuts) {
      executedQty += cut['activityQuantity'];
      ac += cut['cutAc'];
    }

    final ev = totalQty > 0 ? (executedQty / totalQty) * bac : 0.0;
    final cpi = ac > 0 ? ev / ac : 1.0;
    final eac = cpi > 0 ? bac / cpi : bac;
    final etc = eac - ac;

    return EvmMetrics(
      activityId: activityId,
      ac: ac,
      ev: ev,
      cpi: cpi,
      eac: eac,
      bac: bac,
      etc: etc,
      evRecords: cuts,
      acRecords: const [],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getApus({int? projectId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_apus);
  }

  @override
  Future<void> saveCutRecord(int activityId, double activityQuantity, DateTime date, List<Map<String, dynamic>> purchases) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final String cutId = DateTime.now().millisecondsSinceEpoch.toString();
    
    double cutAc = 0.0;
    for (var p in purchases) {
      cutAc += (p['realPrice'] * p['consumedQuantity']);
    }

    _cutRecords.add({
      'id': cutId,
      'apu_id': activityId,
      'cutNumber': _cutRecords.where((c) => c['apu_id'] == activityId).length + 1,
      'activityQuantity': activityQuantity,
      'date': date.toIso8601String(),
      'cutAc': cutAc,
      'purchases': purchases,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getApuInsumos(int activityId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      {'codigo': 'I001', 'descripcion': 'Cemento', 'unidad': 'BTO', 'precioUnitario': 25000.0, 'cantidad': 10.0},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getCutRecordsForApu(int activityId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _cutRecords.where((c) => c['apu_id'] == activityId).toList();
  }
}
