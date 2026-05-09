class Promocion {

  final String id;
  final String titulo;
  final String descripcion;
  final String imagen;
  final String tipo;

  final int bono;

  final bool activo;

  Promocion({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.imagen,
    required this.tipo,
    required this.bono,
    required this.activo,
  });

  factory Promocion.fromJson(
      String id,
      Map<String, dynamic> json,
      ) {

    return Promocion(

      id: id,

      titulo: json['titulo'] ?? '',

      descripcion: json['descripcion'] ?? '',

      imagen: json['imagen'] ?? 'regalo.png',

      tipo: json['tipo'] ?? '',

      bono: (json['bono'] ?? 0).toInt(),

      activo: json['activo'] ?? false,
    );
  }
}