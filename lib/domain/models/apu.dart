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
  final List<ApuItem> items;

  Apu({
    required this.codigo,
    required this.nombre,
    required this.unidad,
    this.items = const [],
  });

  double get costoTotal => items.fold(0.0, (sum, item) => sum + item.costoParcial);

  factory Apu.fromMap(Map<String, dynamic> map, {List<ApuItem> items = const []}) {
    return Apu(
      codigo: map['codigo'] as String,
      nombre: map['nombre'] as String,
      unidad: map['unidad'] as String,
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'unidad': unidad,
    };
  }
}
