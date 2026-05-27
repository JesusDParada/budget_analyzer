import 'package:budget_analyzer/domain/models/evm_metrics.dart';

/// Propósito Específico: Interfaz (Contrato) para el repositorio de EVM.
/// Mapa de Relaciones: Define los métodos que las capas de presentación consumen, permitiendo cambiar
/// la implementación subyacente (Mock, Supabase, etc.) sin afectar el resto del sistema.
abstract class IEvmRepository {
  /// Calcula las métricas EVM (AC, EV, CPI, EAC) para un APU dado.
  Future<EvmMetrics> calculateMetricsForApu(String apuId);

  /// Obtiene la lista de todos los APUs disponibles.
  Future<List<Map<String, dynamic>>> getApus();

  /// Guarda el avance físico de un APU (alimenta el EV).
  Future<void> saveFieldProgress(String apuId, double quantity, DateTime date);

  /// Guarda una salida de inventario (alimenta el AC).
  Future<void> saveInventoryIssue(
    String apuId,
    String materialName,
    double quantity,
    double totalCost,
  );
}
