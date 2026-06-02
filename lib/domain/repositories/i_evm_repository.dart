import 'package:budget_analyzer/domain/models/evm_metrics.dart';

/// Propósito Específico: Interfaz (Contrato) para el repositorio de EVM.
/// Mapa de Relaciones: Define los métodos que las capas de presentación consumen, permitiendo cambiar
/// la implementación subyacente (Mock, SQLite, etc.) sin afectar el resto del sistema.
abstract class IEvmRepository {
  /// Calcula las métricas EVM (AC, EV, CPI, EAC) para un APU dado.
  Future<EvmMetrics> calculateMetricsForApu(int activityId);

  /// Obtiene la lista de todos los APUs disponibles, opcionalmente filtrados por proyecto.
  Future<List<Map<String, dynamic>>> getApus({int? projectId});

  /// Guarda un corte temporal completo (almacén + progreso vinculados)
  Future<void> saveCutRecord(int activityId, double activityQuantity, DateTime date, List<Map<String, dynamic>> purchases);

  /// Guarda un gasto global de insumo distribuyéndolo proporcionalmente en base al BAC
  Future<void> saveGlobalExpense(String insumoDesc, double totalRealPrice, double totalConsumedQty, List<int> selectedActivityIds);

  /// Obtiene los insumos de la APU (desde detalleJson o bd) para mostrar en el formulario
  Future<List<Map<String, dynamic>>> getApuInsumos(int activityId);
  
  /// Obtiene todos los cortes de un APU
  Future<List<Map<String, dynamic>>> getCutRecordsForApu(int activityId);
}
