import 'insumo.dart';

class ApuItem {
  final String apuCodigo;
  final String insumoCodigo;
  final Insumo? insumo;
  final double cantidad;

  ApuItem({
    required this.apuCodigo,
    required this.insumoCodigo,
    this.insumo,
    required this.cantidad,
  });

  double get costoParcial => (insumo?.valorUnitario ?? 0.0) * cantidad;

  factory ApuItem.fromMap(Map<String, dynamic> map, {Insumo? insumo}) {
    return ApuItem(
      apuCodigo: map['apuCodigo'] as String,
      insumoCodigo: map['insumoCodigo'] as String,
      cantidad: (map['cantidad'] as num).toDouble(),
      insumo: insumo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'apuCodigo': apuCodigo,
      'insumoCodigo': insumoCodigo,
      'cantidad': cantidad,
    };
  }
}

class Apu {
  final String codigo;
  final String nombre;
  final String unidad;
  final int? projectId;
  final double cantidad;
  final double valorUnitario;
  final double bac;
  final String? memoriaJson;
  final String? detalleJson;
  final List<ApuItem> items;

  Apu({
    required this.codigo,
    required this.nombre,
    required this.unidad,
    this.projectId,
    this.cantidad = 0.0,
    this.valorUnitario = 0.0,
    this.bac = 0.0,
    this.memoriaJson,
    this.detalleJson,
    this.items = const [],
  });

  double get costoTotal => valorUnitario > 0 ? valorUnitario : items.fold(0.0, (sum, item) => sum + item.costoParcial);

  factory Apu.fromMap(Map<String, dynamic> map, {List<ApuItem> items = const []}) {
    return Apu(
      codigo: map['codigo'] as String,
      nombre: map['nombre'] as String,
      unidad: map['unidad'] as String,
      projectId: map['projectId'] as int?,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      valorUnitario: (map['valorUnitario'] as num?)?.toDouble() ?? 0.0,
      bac: (map['bac'] as num?)?.toDouble() ?? 0.0,
      memoriaJson: map['memoriaJson'] as String?,
      detalleJson: map['detalleJson'] as String?,
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'unidad': unidad,
      if (projectId != null) 'projectId': projectId,
      'cantidad': cantidad,
      'valorUnitario': valorUnitario,
      'bac': bac,
      if (memoriaJson != null) 'memoriaJson': memoriaJson,
      if (detalleJson != null) 'detalleJson': detalleJson,
    };
  }
}
