import 'package:budget_analyzer/domain/models/evm_metrics.dart';
import 'package:budget_analyzer/domain/repositories/i_evm_repository.dart';
import 'package:budget_analyzer/data/local_db/database_helper.dart';
import 'package:budget_analyzer/core/utils/apu_insumos_parser.dart';

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
      final bac = apu.bac > 0 ? apu.bac : (unitPrice * totalQty);

      // Usamos una clave compuesta única por proyecto ("projectId_codigo")
      // para evitar colisiones entre proyectos diferentes con el mismo código.
      final uniqueId = apu.projectId != null ? '${apu.projectId}_${apu.codigo}' : apu.codigo;

      return {
        'id': uniqueId,
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
    // Descomponer el apuId (que puede ser compuesto: "projectId_codigo")
    final parts = apuId.split('_');
    final int? projectId = parts.length > 1 ? int.tryParse(parts[0]) : null;
    final String codigo = parts.length > 1 ? parts.sublist(1).join('_') : apuId;

    // Buscar las APUs del proyecto correspondiente si está disponible
    final apus = projectId != null
        ? await _dbHelper.getApusByProject(projectId)
        : await _dbHelper.getAllApus();

    final apu = apus.firstWhere(
      (a) => a.codigo == codigo,
      orElse: () => throw Exception('APU no encontrado: $apuId'),
    );

    final double unitPrice = apu.valorUnitario > 0 ? apu.valorUnitario : apu.costoTotal;
    final double totalQty = apu.cantidad > 0 ? apu.cantidad : defaultTotalQuantity;
    // Usamos el BAC extraído directamente de la columna G (Vr. Parcial) si está disponible, sino lo calculamos
    final double bac = apu.bac > 0 ? apu.bac : (unitPrice * totalQty);

    // Obtener Cortes (CutRecords) para calcular AC y EV
    final cutRecords = await _dbHelper.getCutRecordsForApu(apuId);
    
    double ac = 0.0;
    double executedQuantity = 0.0;
    
    // Lista de registros para la UI
    List<Map<String, dynamic>> cutRecordsUI = [];

    for (var cut in cutRecords) {
      final String cutId = cut['id'];
      final double cutActQty = cut['activityQuantity'] as double;
      final int cutNumber = cut['cutNumber'] as int;
      final String cutDate = cut['date'] as String;
      
      executedQuantity += cutActQty;
      
      // Obtener compras de insumos para este corte
      final purchases = await _dbHelper.getPurchasesForCut(cutId);
      double cutInsumosCost = 0.0;
      
      for (var p in purchases) {
        final double realPrice = p['realPrice'] as double;
        final double consumedQty = p['consumedQuantity'] as double;
        cutInsumosCost += (realPrice * consumedQty);
      }
      
      final double cutAc = cutInsumosCost; // AC es la suma de los insumos consumidos
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

    // Calcular índices
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
      evRecords: cutRecordsUI, // Usamos evRecords para mandar los cortes a la UI
      acRecords: const [],
    );
  }

  @override
  Future<void> saveCutRecord(String apuId, double activityQuantity, DateTime date, List<Map<String, dynamic>> purchases) async {
    final existingCuts = await _dbHelper.getCutRecordsForApu(apuId);
    final int nextCutNumber = existingCuts.length + 1;
    final String cutId = DateTime.now().millisecondsSinceEpoch.toString();

    final cutMap = {
      'id': cutId,
      'apuCodigo': apuId,
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
  Future<List<Map<String, dynamic>>> getApuInsumos(String apuId) async {
    final parts = apuId.split('_');
    final int? projectId = parts.length > 1 ? int.tryParse(parts[0]) : null;
    final String codigo = parts.length > 1 ? parts.sublist(1).join('_') : apuId;

    final apus = projectId != null
        ? await _dbHelper.getApusByProject(projectId)
        : await _dbHelper.getAllApus();

    final apu = apus.firstWhere(
      (a) => a.codigo == codigo,
      orElse: () => throw Exception('APU no encontrado: $apuId'),
    );

    final insumos = ApuInsumosParser.parse(apu.detalleJson);
    return insumos.map((i) => i.toMap()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getCutRecordsForApu(String apuId) async {
    return await _dbHelper.getCutRecordsForApu(apuId);
  }
}
