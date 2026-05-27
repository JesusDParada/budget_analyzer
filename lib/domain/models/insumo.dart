class Insumo {
  final String codigo;
  final String descripcion;
  final String unidad;
  final double valorUnitario;
  final String tipo; 

  Insumo({
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.valorUnitario,
    required this.tipo,
  });

  factory Insumo.fromMap(Map<String, dynamic> map) {
    return Insumo(
      codigo: map['codigo'] as String,
      descripcion: map['descripcion'] as String,
      unidad: map['unidad'] as String,
      valorUnitario: (map['valorUnitario'] as num).toDouble(),
      tipo: map['tipo'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'unidad': unidad,
      'valorUnitario': valorUnitario,
      'tipo': tipo,
    };
  }
}
