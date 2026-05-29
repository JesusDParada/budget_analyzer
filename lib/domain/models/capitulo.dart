import 'apu.dart';

class Capitulo {
  final int? id;
  final int projectId;
  final int numero;
  final String nombre;
  final List<Apu> apus;

  Capitulo({
    this.id,
    required this.projectId,
    required this.numero,
    required this.nombre,
    this.apus = const [],
  });

  factory Capitulo.fromMap(Map<String, dynamic> map, {List<Apu> apus = const []}) {
    return Capitulo(
      id: map['id'] as int?,
      projectId: map['projectId'] as int,
      numero: map['numero'] as int,
      nombre: map['nombre'] as String,
      apus: apus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'projectId': projectId,
      'numero': numero,
      'nombre': nombre,
    };
  }
}
