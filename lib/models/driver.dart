import 'dart:convert';

Driver driverFromJson(String str) => Driver.fromJson(json.decode(str));

String driverToJson(Driver data) => json.encode(data.toJson());

class Driver {
  String id;
  String rol;
  String the01Nombres;
  String the02Apellidos;
  String the07Celular;
  String the29FotoPerfil;
  int the30NumeroViajes;
  double the31Calificacion;
  String token;
  String image;

  double? ratingAvg;
  int? ratingCount;
  String vehiculoActivoId;


  Driver({
    required this.id,
    required this.rol,
    required this.the01Nombres,
    required this.the02Apellidos,
    required this.the07Celular,
    required this.the29FotoPerfil,
    required this.the30NumeroViajes,
    required this.the31Calificacion,
    required this.token,
    required this.image,
    required this.ratingAvg,
    required this.ratingCount,
    required this.vehiculoActivoId,

  });

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json["id"] ?? "",
    rol: json["rol"] ?? "",

    the01Nombres: json["01_Nombres"] ?? "",
    the02Apellidos: json["02_Apellidos"] ?? "",
    the07Celular: json["07_Celular"] ?? "",

    the29FotoPerfil: json["29_Foto_perfil"] ?? "",

    the30NumeroViajes: json["30_Numero_viajes"] ?? 0,
    the31Calificacion: (json["31_Calificacion"] as num?)?.toDouble() ?? 0.0,

    token: json["token"] ?? "",
    image: json["image"] ?? "",

    ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
    ratingCount: (json['rating_count'] as num?)?.toInt(),

    vehiculoActivoId: json["vehiculoActivoId"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "rol": rol,
    "01_Nombres": the01Nombres,
    "02_Apellidos": the02Apellidos,
    "07_Celular": the07Celular,
    "29_Foto_perfil": the29FotoPerfil,
    "30_Numero_viajes": the30NumeroViajes,
    "31_Calificacion": the31Calificacion,
    "token": token,
    "image": image,
    'rating_avg': ratingAvg,
    'rating_count': ratingCount,
    'vehiculoActivoId': vehiculoActivoId,

  };
}