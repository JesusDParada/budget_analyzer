// VULNERABILIDAD: Datos manejados en memoria.
// RIESGO: Si la aplicación se cierra, los datos no persisten.
// SOLUCIÓN SUGERIDA: Implementar persistencia real (Supabase) cuando el flujo UI esté validado.

import 'package:budget_analyzer/domain/models/evm_metrics.dart';
import 'package:budget_analyzer/domain/repositories/i_evm_repository.dart';

/// Propósito Específico: Implementación Mock del repositorio de EVM para pruebas de UI y cálculos locales.
class MockEvmRepositoryImpl implements IEvmRepository {
  final List<Map<String, dynamic>> _apus = [
    {'id': 'apu-1', 'code': 'APU-001', 'description': 'Excavación manual', 'unit_measure': 'm3', 'total_quantity': 100.0, 'unit_price': 100.0, 'bac': 10000.0},
    {'id': 'apu-2', 'code': 'APU-002', 'description': 'Concreto 3000 PSI', 'unit_measure': 'm3', 'total_quantity': 50.0, 'unit_price': 300.0, 'bac': 15000.0},
  ];
  
  final List<Map<String, dynamic>> _inventoryIssues = [];
  final List<Map<String, dynamic>> _fieldProgress = [];

  @override
  Future<EvmMetrics> calculateMetricsForApu(String apuId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final apuData = _apus.firstWhere((apu) => apu['id'] == apuId, orElse: () => throw Exception('APU no encontrado'));
    final double bac = apuData['bac'];
    final double totalQuantity = apuData['total_quantity'];

    final double materialsCost = _inventoryIssues
        .where((issue) => issue['apu_id'] == apuId)
        .fold(0.0, (sum, item) => sum + item['total_cost']);
    final double ac = materialsCost;

    final double executedQuantity = _fieldProgress
        .where((progress) => progress['apu_id'] == apuId)
        .fold(0.0, (sum, item) => sum + item['executed_quantity']);
    final double ev = totalQuantity > 0 ? (executedQuantity / totalQuantity) * bac : 0.0;

    final double cpi = ac > 0 ? ev / ac : (ev > 0 ? double.infinity : 1.0); 
    final double eac = cpi > 0 && cpi != double.infinity ? bac / cpi : bac;

    return EvmMetrics(
      apuId: apuId,
      ac: ac,
      ev: ev,
      cpi: cpi,
      eac: eac,
      bac: bac,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getApus() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_apus);
  }

  @override
  Future<void> saveFieldProgress(String apuId, double quantity, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _fieldProgress.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'apu_id': apuId,
      'date': date,
      'executed_quantity': quantity,
    });
  }

  @override
  Future<void> saveInventoryIssue(String apuId, String materialName, double quantity, double totalCost) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _inventoryIssues.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'apu_id': apuId,
      'material_name': materialName,
      'quantity_issued': quantity,
      'total_cost': totalCost,
    });
  }
}
