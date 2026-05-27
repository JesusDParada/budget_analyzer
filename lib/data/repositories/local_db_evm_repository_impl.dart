import 'package:budget_analyzer/domain/models/evm_metrics.dart';
import 'package:budget_analyzer/domain/repositories/i_evm_repository.dart';
import 'package:budget_analyzer/data/local_db/database_helper.dart';

class LocalDbEvmRepositoryImpl implements IEvmRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Cantidad total por defecto si no se especifica o lee en el Excel
  final double defaultTotalQuantity = 100.0;

  @override
  Future<List<Map<String, dynamic>>> getApus({int? projectId}) async {
    final apus = projectId != null
        ? await _dbHelper.getApusByProject(projectId)
        : await _dbHelper.getAllApus();
    
    return apus.map((apu) {
      final unitPrice = apu.valorUnitario > 0 ? apu.valorUnitario : apu.costoTotal;
      final totalQty = apu.cantidad > 0 ? apu.cantidad : defaultTotalQuantity;
      final bac = unitPrice * totalQty;

      return {
        'id': apu.codigo, // Usamos el código como ID único
        'code': apu.codigo,
        'description': apu.nombre,
        'unit_measure': apu.unidad,
        'total_quantity': totalQty,
        'unit_price': unitPrice,
        'bac': bac,
      };
    }).toList();
  }

  @override
  Future<EvmMetrics> calculateMetricsForApu(String apuId) async {
    final apus = await _dbHelper.getAllApus();
    final apu = apus.firstWhere(
      (a) => a.codigo == apuId,
      orElse: () => throw Exception('APU no encontrado: $apuId'),
    );

    final double unitPrice = apu.valorUnitario > 0 ? apu.valorUnitario : apu.costoTotal;
    final double totalQty = apu.cantidad > 0 ? apu.cantidad : defaultTotalQuantity;
    final double bac = unitPrice * totalQty;

    // Obtener AC (Actual Cost) sumando salidas de almacén
    final inventoryIssues = await _dbHelper.getInventoryIssuesForApu(apuId);
    final double ac = inventoryIssues.fold(0.0, (sum, issue) => sum + (issue['totalCost'] as double));

    // Obtener EV (Earned Value)
    final fieldProgress = await _dbHelper.getFieldProgressForApu(apuId);
    final double executedQuantity = fieldProgress.fold(0.0, (sum, progress) => sum + (progress['quantity'] as double));
    final double ev = totalQty > 0 ? (executedQuantity / totalQty) * bac : 0.0;

    // Calcular índices
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
  Future<void> saveInventoryIssue(String apuId, String materialName, double quantity, double totalCost) async {
    final issueMap = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'apuCodigo': apuId,
      'materialName': materialName,
      'quantity': quantity,
      'totalCost': totalCost,
      'date': DateTime.now().toIso8601String(),
    };
    await _dbHelper.insertInventoryIssue(issueMap);
  }

  @override
  Future<void> saveFieldProgress(String apuId, double quantity, DateTime date) async {
    final progressMap = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'apuCodigo': apuId,
      'quantity': quantity,
      'date': date.toIso8601String(),
    };
    await _dbHelper.insertFieldProgress(progressMap);
  }
}
