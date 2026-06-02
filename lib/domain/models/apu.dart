import 'insumo.dart';

class Apu {
  final int? id;
  final String codigo;
  final String nombre;
  final String unidad;
  final double cantidad;
  final double valorUnitario;
  final double bac;
  final String? memoriaJson;
  final String? detalleJson;
  final int? capituloId;
  final List<Insumo> insumos;

  Apu({
    this.id,
    required this.codigo,
    required this.nombre,
    required this.unidad,
    this.cantidad = 0.0,
    this.valorUnitario = 0.0,
    this.bac = 0.0,
    this.memoriaJson,
    this.detalleJson,
    this.capituloId,
    this.insumos = const [],
  });

  double get costoTotal => valorUnitario > 0 ? valorUnitario : insumos.fold(0.0, (sum, i) => sum + i.costoParcial);

  factory Apu.fromMap(Map<String, dynamic> map, {List<Insumo> insumos = const []}) {
    return Apu(
      id: map['id'] as int?,
      codigo: map['codigo'] as String,
      nombre: map['nombre'] as String,
      unidad: map['unidad'] as String,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      valorUnitario: (map['valorUnitario'] as num?)?.toDouble() ?? 0.0,
      bac: (map['bac'] as num?)?.toDouble() ?? 0.0,
      memoriaJson: map['memoriaJson'] as String?,
      detalleJson: map['detalleJson'] as String?,
      capituloId: map['capituloId'] as int?,
      insumos: insumos,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'unidad': unidad,
      'cantidad': cantidad,
      'valorUnitario': valorUnitario,
      'bac': bac,
      if (memoriaJson != null) 'memoriaJson': memoriaJson,
      if (detalleJson != null) 'detalleJson': detalleJson,
      if (capituloId != null) 'capituloId': capituloId,
    };
  }
}
