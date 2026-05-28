import 'package:budget_analyzer/domain/models/evm_metrics.dart';

/// Propósito Específico: Interfaz (Contrato) para el repositorio de EVM.
/// Mapa de Relaciones: Define los métodos que las capas de presentación consumen, permitiendo cambiar
/// la implementación subyacente (Mock, SQLite, etc.) sin afectar el resto del sistema.
abstract class IEvmRepository {
  /// Calcula las métricas EVM (AC, EV, CPI, EAC) para un APU dado.
  Future<EvmMetrics> calculateMetricsForApu(String apuId);

  /// Obtiene la lista de todos los APUs disponibles, opcionalmente filtrados por proyecto.
  Future<List<Map<String, dynamic>>> getApus({int? projectId});

  /// Guarda un corte temporal completo (almacén + progreso vinculados)
  Future<void> saveCutRecord(String apuId, double activityQuantity, DateTime date, List<Map<String, dynamic>> purchases);

  /// Obtiene los insumos de la APU (desde detalleJson) para mostrar en el formulario
  Future<List<Map<String, dynamic>>> getApuInsumos(String apuId);
  
  /// Obtiene todos los cortes de un APU
  Future<List<Map<String, dynamic>>> getCutRecordsForApu(String apuId);
}
