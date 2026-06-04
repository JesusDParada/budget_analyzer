/// Métricas EVM agregadas a nivel de capítulo.
/// Se calculan sumando/promediando las métricas individuales de cada APU del capítulo.
class ChapterMetrics {
  final int capituloId;
  final double bac;
  final double ac;
  final double ev;
  final double eac;
  final double etc;
  final double cpiPromedio;
  final int apuCount;

  ChapterMetrics({
    required this.capituloId,
    required this.bac,
    required this.ac,
    required this.ev,
    required this.eac,
    required this.etc,
    required this.cpiPromedio,
    required this.apuCount,
  });
}
