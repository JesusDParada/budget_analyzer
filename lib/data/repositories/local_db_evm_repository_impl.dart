import 'package:budget_analyzer/domain/models/evm_metrics.dart';
import 'package:budget_analyzer/domain/repositories/i_evm_repository.dart';
import 'package:budget_analyzer/data/local_db/database_helper.dart';

class LocalDbEvmRepositoryImpl implements IEvmRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final double defaultTotalQuantity = 100.0;

  @override
  Future<List<Map<String, dynamic>>> getApus({int? projectId}) async {
    final apus = projectId != null
        ? await _dbHelper.getApusByProject(projectId)
        : await _dbHelper.getAllApus();
    
    return apus.map((apu) {
      final unitPrice = apu.valorUnitario > 0 ? apu.valorUnitario : apu.costoTotal;
      final totalQty = apu.cantidad > 0 ? apu.cantidad : defaultTotalQuantity;
      final bac = apu.bac > 0 ? apu.bac : (unitPrice * totalQty);

      return {
        'id': apu.id,
        'code': apu.codigo,
        'description': apu.nombre,
        'unit_measure': apu.unidad,
        'total_quantity': totalQty,
        'unit_price': unitPrice,
        'bac': bac,
        'capituloId': apu.capituloId,
      };
    }).toList();
  }

  @override
  Future<EvmMetrics> calculateMetricsForApu(int activityId) async {
    final apus = await _dbHelper.getAllApus();

    final apu = apus.firstWhere(
      (a) => a.id == activityId,
      orElse: () => throw Exception('Activity no encontrada: $activityId'),
    );

    final double unitPrice = apu.valorUnitario > 0 ? apu.valorUnitario : apu.costoTotal;
    final double totalQty = apu.cantidad > 0 ? apu.cantidad : defaultTotalQuantity;
    final double bac = apu.bac > 0 ? apu.bac : (unitPrice * totalQty);

    final cutRecords = await _dbHelper.getCutRecordsForActivity(activityId);
    
    double ac = 0.0;
    double executedQuantity = 0.0;
    List<Map<String, dynamic>> cutRecordsUI = [];

    for (var cut in cutRecords) {
      final String cutId = cut['id'];
      final double cutActQty = cut['activityQuantity'] as double;
      final int cutNumber = cut['cutNumber'] as int;
      final String cutDate = cut['date'] as String;
      
      executedQuantity += cutActQty;
      
      final purchases = await _dbHelper.getPurchasesForCut(cutId);
      double cutInsumosCost = 0.0;
      
      for (var p in purchases) {
        final double realPrice = p['realPrice'] as double;
        final double consumedQty = p['consumedQuantity'] as double;
        cutInsumosCost += (realPrice * consumedQty);
      }
      
      final double cutAc = cutInsumosCost;
      ac += cutAc;
      
      cutRecordsUI.add({
        'cutNumber': cutNumber,
        'date': cutDate,
        'activityQuantity': cutActQty,
        'insumosCost': cutInsumosCost,
        'cutAc': cutAc,
        'purchases': purchases,
      });
    }

    final double ev = totalQty > 0 ? (executedQuantity / totalQty) * bac : 0.0;

    final double cpi = ac > 0 ? ev / ac : (ev > 0 ? double.infinity : 1.0);
    final double eac = cpi > 0 && cpi != double.infinity ? bac / cpi : bac;
    final double etc = eac - ac;

    return EvmMetrics(
      activityId: activityId,
      ac: ac,
      ev: ev,
      cpi: cpi,
      eac: eac,
      bac: bac,
      etc: etc,
      evRecords: cutRecordsUI,
      acRecords: const [],
    );
  }

  @override
  Future<void> saveCutRecord(int activityId, double activityQuantity, DateTime date, List<Map<String, dynamic>> purchases) async {
    final existingCuts = await _dbHelper.getCutRecordsForActivity(activityId);
    final int nextCutNumber = existingCuts.length + 1;
    final String cutId = DateTime.now().millisecondsSinceEpoch.toString();

    final cutMap = {
      'id': cutId,
      'activityId': activityId,
      'cutNumber': nextCutNumber,
      'activityQuantity': activityQuantity,
      'date': date.toIso8601String(),
    };

    List<Map<String, dynamic>> purchaseMaps = purchases.map((p) {
      return {
        'id': '${DateTime.now().microsecondsSinceEpoch}_${p.hashCode}',
        'cutRecordId': cutId,
        'insumoDescription': p['insumoDescription'],
        'realPrice': p['realPrice'],
        'purchasedQuantity': p['purchasedQuantity'],
        'consumedQuantity': p['consumedQuantity'],
      };
    }).toList();

    await _dbHelper.insertCutRecord(cutMap, purchaseMaps);
  }

  @override
  Future<List<Map<String, dynamic>>> getApuInsumos(int activityId) async {
    final apus = await _dbHelper.getAllApus();
    final apu = apus.firstWhere(
      (a) => a.id == activityId,
      orElse: () => throw Exception('Activity no encontrada: $activityId'),
    );

    // Now returning the insumos directly from the unified database table!
    return apu.insumos.map((i) => i.toMap()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getCutRecordsForApu(int activityId) async {
    return await _dbHelper.getCutRecordsForActivity(activityId);
  }
}
