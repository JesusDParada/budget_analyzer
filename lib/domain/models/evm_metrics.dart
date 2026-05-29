/// Propósito Específico: Modelo que representa las métricas principales de EVM para un APU.
/// Mapa de Relaciones: Usado por el repositorio de EVM para retornar los cálculos y consumido por la UI.
class EvmMetrics {
  final int activityId;
  final double ac;
  final double ev;
  final double cpi;
  final double eac;
  final double bac;
  final double etc;
  final List<Map<String, dynamic>> evRecords;
  final List<Map<String, dynamic>> acRecords;

  EvmMetrics({
    required this.activityId,
    required this.ac,
    required this.ev,
    required this.cpi,
    required this.eac,
    required this.bac,
    required this.etc,
    this.evRecords = const [],
    this.acRecords = const [],
  });
}
