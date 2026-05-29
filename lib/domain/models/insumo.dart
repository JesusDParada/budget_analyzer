class Insumo {
  final int? id;
  final int activityId;
  final String descripcion;
  final String unidad;
  final double valorUnitario;
  final double cantidad;

  Insumo({
    this.id,
    required this.activityId,
    required this.descripcion,
    required this.unidad,
    required this.valorUnitario,
    required this.cantidad,
  });

  double get costoParcial => valorUnitario * cantidad;

  factory Insumo.fromMap(Map<String, dynamic> map) {
    return Insumo(
      id: map['id'] as int?,
      activityId: map['activityId'] as int,
      descripcion: map['descripcion'] as String,
      unidad: map['unidad'] as String,
      valorUnitario: (map['valorUnitario'] as num).toDouble(),
      cantidad: (map['cantidad'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'activityId': activityId,
      'descripcion': descripcion,
      'unidad': unidad,
      'valorUnitario': valorUnitario,
      'cantidad': cantidad,
    };
  }
}
