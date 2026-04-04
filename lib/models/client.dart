import 'dart:convert';

Client clientFromJson(String str) => Client.fromJson(json.decode(str));
String clientToJson(Client data) => json.encode(data.toJson());

class Client {
  String id;
  String nombres;
  String apellidos;
  String celular;
  String genero;

  int bono;
  double calificacion;
  int viajes;

  String rol;
  String fechaRegistro;
  String token;
  String status;

  bool isTraveling;
  int cancelaciones;
  bool suspendido;

  String palabraClave;
  String preguntaPalabraClave;

  // 🔥 NUEVO SISTEMA LIMPIO
  String fotoPerfilUrl;
  String fotoPerfilEstado;

  String cedulaFrontalUrl;
  String cedulaFrontalEstado;

  String cedulaReversoUrl;
  String cedulaReversoEstado;

  String nombreEstado;

  Client({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.celular,
    required this.genero,
    required this.bono,
    required this.calificacion,
    required this.viajes,
    required this.rol,
    required this.fechaRegistro,
    required this.token,
    required this.status,
    required this.isTraveling,
    required this.cancelaciones,
    required this.suspendido,
    required this.palabraClave,
    required this.preguntaPalabraClave,

    required this.fotoPerfilUrl,
    required this.fotoPerfilEstado,
    required this.cedulaFrontalUrl,
    required this.cedulaFrontalEstado,
    required this.cedulaReversoUrl,
    required this.cedulaReversoEstado,

    required this.nombreEstado,
  });

  // helpers
  static int _toInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? def;
    return def;
  }

  static double _toDouble(dynamic v, {double def = 0.0}) {
    if (v == null) return def;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? def;
    return def;
  }

  static bool _toBool(dynamic v, {bool def = false}) {
    if (v == null) return def;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
    }
    return def;
  }

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: (json["id"] ?? '').toString(),
    nombres: (json["01_Nombres"] ?? '').toString(),
    apellidos: (json["02_Apellidos"] ?? '').toString(),
    celular: (json["07_Celular"] ?? '').toString(),
    genero: (json["09_Genero"] ?? '').toString(),

    bono: _toInt(json["17_Bono"]),
    calificacion: _toDouble(json["18_Calificacion"]),
    viajes: _toInt(json["19_Viajes"]),

    rol: (json["20_Rol"] ?? '').toString(),
    fechaRegistro: (json["21_Fecha_de_registro"] ?? '').toString(),
    token: (json["token"] ?? '').toString(),
    status: (json["status"] ?? '').toString(),

    isTraveling: _toBool(json["00_is_traveling"]),
    cancelaciones: _toInt(json["22_cancelaciones"]),
    suspendido: _toBool(json["41_Suspendido_Por_Cancelaciones"]),

    palabraClave: (json["palabra_clave"] ?? '').toString(),
    preguntaPalabraClave: (json["pregunta_palabra_clave"] ?? '').toString(),

    // 🔥 NUEVO SISTEMA
    fotoPerfilUrl: (json["foto_perfil_url"] ?? '').toString(),
    fotoPerfilEstado: (json["foto_perfil_estado"] ?? '').toString(),

    cedulaFrontalUrl: (json["cedula_frontal_url"] ?? '').toString(),
    cedulaFrontalEstado: (json["cedula_frontal_estado"] ?? '').toString(),

    cedulaReversoUrl: (json["cedula_reverso_url"] ?? '').toString(),
    cedulaReversoEstado: (json["cedula_reverso_estado"] ?? '').toString(),

    nombreEstado: (json["nombre_estado"] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "01_Nombres": nombres,
    "02_Apellidos": apellidos,
    "07_Celular": celular,
    "09_Genero": genero,

    "17_Bono": bono,
    "18_Calificacion": calificacion,
    "19_Viajes": viajes,

    "20_Rol": rol,
    "21_Fecha_de_registro": fechaRegistro,
    "token": token,
    "status": status,

    "00_is_traveling": isTraveling,
    "22_cancelaciones": cancelaciones,
    "41_Suspendido_Por_Cancelaciones": suspendido,

    "palabra_clave": palabraClave,
    "pregunta_palabra_clave": preguntaPalabraClave,

    // 🔥 NUEVO SISTEMA
    "foto_perfil_url": fotoPerfilUrl,
    "foto_perfil_estado": fotoPerfilEstado,

    "cedula_frontal_url": cedulaFrontalUrl,
    "cedula_frontal_estado": cedulaFrontalEstado,

    "cedula_reverso_url": cedulaReversoUrl,
    "cedula_reverso_estado": cedulaReversoEstado,

    "nombre_estado": nombreEstado,
  };
}