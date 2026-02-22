import 'dart:convert';

Client clientFromJson(String str) => Client.fromJson(json.decode(str));
String clientToJson(Client data) => json.encode(data.toJson());

class Client {
  String id;
  String the01Nombres;
  String the02Apellidos;
  String the06Email;
  String the07Celular;
  String the09Genero;
  String the15FotoPerfilUsuario;
  int the17Bono;
  double the18Calificacion;
  int the19Viajes;
  String the20Rol;
  String the21FechaDeRegistro;
  String token;
  String image;
  String status;
  bool the00isTraveling;
  int the22Cancelaciones;
  bool the41SuspendidoPorCancelaciones;
  bool fotoPerfilTomada;
  String palabraClave;
  String preguntaPalabraClave;

  // ✅ Cédula
  String the16CedulaFrontalUsuario;
  bool cedulaFrontalTomada;
  String the23CedulaReversoUsuario;
  bool cedulaReversoTomada;

  Client({
    required this.id,
    required this.the01Nombres,
    required this.the02Apellidos,
    required this.the06Email,
    required this.the07Celular,
    required this.the09Genero,
    required this.the15FotoPerfilUsuario,
    required this.the17Bono,
    required this.the18Calificacion,
    required this.the19Viajes,
    required this.the20Rol,
    required this.the21FechaDeRegistro,
    required this.token,
    required this.image,
    required this.status,
    required this.the00isTraveling,
    required this.the22Cancelaciones,
    required this.the41SuspendidoPorCancelaciones,
    required this.fotoPerfilTomada,
    required this.palabraClave,
    required this.preguntaPalabraClave,
    required this.the16CedulaFrontalUsuario,
    required this.cedulaFrontalTomada,
    required this.the23CedulaReversoUsuario,
    required this.cedulaReversoTomada,
  });

  // =========================
  // Helpers de parseo seguro
  // =========================
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
      final s = v.trim().toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
      // por si guardaron "1"/"0"
      final n = int.tryParse(s);
      if (n != null) return n != 0;
    }
    return def;
  }

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: (json["id"] ?? '').toString(),
    the01Nombres: (json["01_Nombres"] ?? '').toString(),
    the02Apellidos: (json["02_Apellidos"] ?? '').toString(),
    the06Email: (json["06_Email"] ?? '').toString(),
    the07Celular: (json["07_Celular"] ?? '').toString(),
    the09Genero: (json["09_Genero"] ?? '').toString(),
    the15FotoPerfilUsuario: (json["15_Foto_perfil_usuario"] ?? '').toString(),

    // ✅ NUMÉRICOS (nunca uses '' aquí)
    the17Bono: _toInt(json["17_Bono"]),
    the18Calificacion: _toDouble(json["18_Calificacion"]),
    the19Viajes: _toInt(json["19_Viajes"]),

    the20Rol: (json["20_Rol"] ?? '').toString(),
    the21FechaDeRegistro: (json["21_Fecha_de_registro"] ?? '').toString(),
    token: (json["token"] ?? '').toString(),
    image: (json["image"] ?? '').toString(),
    status: (json["status"] ?? '').toString(),

    // ✅ BOOL
    the00isTraveling: _toBool(json["00_is_traveling"]),
    the22Cancelaciones: _toInt(json["22_cancelaciones"]),
    the41SuspendidoPorCancelaciones: _toBool(json["41_Suspendido_Por_Cancelaciones"]),
    fotoPerfilTomada: _toBool(json["foto_perfil_tomada"]),

    palabraClave: (json["palabra_clave"] ?? '').toString(),
    preguntaPalabraClave: (json["pregunta_palabra_clave"] ?? '').toString(),

    the16CedulaFrontalUsuario: (json["16_Cedula_frontal_usuario"] ?? '').toString(),
    cedulaFrontalTomada: _toBool(json["cedula_frontal_tomada"]),
    the23CedulaReversoUsuario: (json["23_Cedula_reverso_usuario"] ?? '').toString(),
    cedulaReversoTomada: _toBool(json["cedula_reverso_tomada"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "01_Nombres": the01Nombres,
    "02_Apellidos": the02Apellidos,
    "06_Email": the06Email,
    "07_Celular": the07Celular,
    "09_Genero": the09Genero,
    "15_Foto_perfil_usuario": the15FotoPerfilUsuario,

    // ✅ NUMÉRICOS correctos
    "17_Bono": the17Bono,
    "18_Calificacion": the18Calificacion,
    "19_Viajes": the19Viajes,

    "20_Rol": the20Rol,
    "21_Fecha_de_registro": the21FechaDeRegistro,
    "token": token,
    "image": image,
    "status": status,

    // ✅ BOOL/INT correctos
    "00_is_traveling": the00isTraveling,
    "22_cancelaciones": the22Cancelaciones,
    "41_Suspendido_Por_Cancelaciones": the41SuspendidoPorCancelaciones,
    "foto_perfil_tomada": fotoPerfilTomada,

    "palabra_clave": palabraClave,
    "pregunta_palabra_clave": preguntaPalabraClave,

    "16_Cedula_frontal_usuario": the16CedulaFrontalUsuario,
    "cedula_frontal_tomada": cedulaFrontalTomada,
    "23_Cedula_reverso_usuario": the23CedulaReversoUsuario,
    "cedula_reverso_tomada": cedulaReversoTomada,
  };
}