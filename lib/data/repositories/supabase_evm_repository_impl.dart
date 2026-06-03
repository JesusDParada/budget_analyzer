import 'package:budget_analyzer/domain/models/evm_metrics.dart';
import 'package:budget_analyzer/domain/repositories/i_evm_repository.dart';
import 'package:budget_analyzer/data/supabase/supabase_helper.dart';

class SupabaseEvmRepositoryImpl implements IEvmRepository {
  final SupabaseHelper _dbHelper = SupabaseHelper.instance;

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
      final int cutId = cut['id'] as int;
      final double cutActQty = (cut['activityQuantity'] as num).toDouble();
      final int cutNumber = cut['cutNumber'] as int;
      final String cutDate = cut['date'] as String;
      
      executedQuantity += cutActQty;
      
      final purchases = await _dbHelper.getPurchasesForCut(cutId);
      double cutInsumosCost = 0.0;
      
      for (var p in purchases) {
        final double realPrice = (p['realPrice'] as num).toDouble();
        final double consumedQty = (p['consumedQuantity'] as num).toDouble();
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
    final openCut = await _dbHelper.getOpenCutRecordForActivity(activityId);

    final apuInsumos = await getApuInsumos(activityId);
    final insumoIdMap = {
      for (var i in apuInsumos)
        i['descripcion']?.toString().toLowerCase().trim(): i['id'] as int?
    };

    List<Map<String, dynamic>> purchaseMaps = purchases.map((p) {
      final desc = p['insumoDescription']?.toString() ?? '';
      final insumoId = insumoIdMap[desc.toLowerCase().trim()];
      return {
        if (insumoId != null) 'insumoId': insumoId,
        'insumoDescription': desc,
        'realPrice': p['realPrice'],
        'purchasedQuantity': p['purchasedQuantity'],
        'consumedQuantity': p['consumedQuantity'],
      };
    }).toList();

    if (openCut != null) {
      final updatedCut = Map<String, dynamic>.from(openCut);
      updatedCut['activityQuantity'] = activityQuantity;
      updatedCut['date'] = date.toIso8601String();
      updatedCut['isClosed'] = 1;
      await _dbHelper.updateCutRecord(openCut['id'] as int, updatedCut);

      for (var pMap in purchaseMaps) {
        await _dbHelper.insertPurchaseIntoCut(openCut['id'] as int, pMap);
      }
    } else {
      final existingCuts = await _dbHelper.getCutRecordsForActivity(activityId);
      final int nextCutNumber = existingCuts.length + 1;
      final cutMap = {
        'activityId': activityId,
        'cutNumber': nextCutNumber,
        'activityQuantity': activityQuantity,
        'date': date.toIso8601String(),
        'isClosed': 1,
      };
      await _dbHelper.insertCutRecord(cutMap, purchaseMaps);
    }
  }

  @override
  Future<void> saveGlobalExpense(String insumoDesc, double totalRealPrice, double totalConsumedQty, List<int> selectedActivityIds) async {
    if (selectedActivityIds.isEmpty) return;

    final allApus = await _dbHelper.getAllApus();
    double totalBac = 0.0;
    final selectedApus = allApus.where((a) => selectedActivityIds.contains(a.id)).toList();

    for (var apu in selectedApus) {
      final unitPrice = apu.valorUnitario > 0 ? apu.valorUnitario : apu.costoTotal;
      final totalQty = apu.cantidad > 0 ? apu.cantidad : defaultTotalQuantity;
      final bac = apu.bac > 0 ? apu.bac : (unitPrice * totalQty);
      totalBac += bac;
    }

    if (totalBac <= 0) totalBac = 1.0;

    for (var apu in selectedApus) {
      final unitPrice = apu.valorUnitario > 0 ? apu.valorUnitario : apu.costoTotal;
      final totalQty = apu.cantidad > 0 ? apu.cantidad : defaultTotalQuantity;
      final bac = apu.bac > 0 ? apu.bac : (unitPrice * totalQty);

      final double fraction = bac / totalBac;
      final double apportionedQty = totalConsumedQty * fraction;

      if (apportionedQty <= 0) continue;

      var openCut = await _dbHelper.getOpenCutRecordForActivity(apu.id!);
      int cutId;
      if (openCut == null) {
        final existingCuts = await _dbHelper.getCutRecordsForActivity(apu.id!);
        final int nextCutNumber = existingCuts.length + 1;
        final cutMap = {
          'activityId': apu.id,
          'cutNumber': nextCutNumber,
          'activityQuantity': 0.0,
          'date': DateTime.now().toIso8601String(),
          'isClosed': 0,
        };
        cutId = await _dbHelper.insertCutRecord(cutMap, []);
      } else {
        cutId = openCut['id'] as int;
      }

      final purchaseMap = <String, dynamic>{
        'insumoDescription': insumoDesc,
        'realPrice': totalRealPrice,
        'purchasedQuantity': 0.0,
        'consumedQuantity': apportionedQty,
      };

      final insumoIdMap = {
        for (var i in apu.insumos)
          i.descripcion.toLowerCase().trim(): i.id
      };
      
      final insumoId = insumoIdMap[insumoDesc.toLowerCase().trim()];
      if (insumoId != null) {
        purchaseMap['insumoId'] = insumoId;
      }

      await _dbHelper.insertPurchaseIntoCut(cutId, purchaseMap);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getApuInsumos(int activityId) async {
    final apus = await _dbHelper.getAllApus();
    final apu = apus.firstWhere(
      (a) => a.id == activityId,
      orElse: () => throw Exception('Activity no encontrada: $activityId'),
    );

    return apu.insumos.map((i) => i.toMap()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getCutRecordsForApu(int activityId) async {
    return await _dbHelper.getCutRecordsForActivity(activityId);
  }
}
