import 'dart:convert';

Driver driverFromJson(String str) => Driver.fromJson(json.decode(str));

String driverToJson(Driver data) => json.encode(data.toJson());

class Driver {
  String id;
  String rol;
  String the01Nombres;
  String the02Apellidos;
  String the07Celular;
  String the14TipoVehiculo;
  String the15Marca;
  String the16Color;
  String the17Modelo;
  String the18Placa;
  String the19TipoServicio;
  String the29FotoPerfil;
  int the30NumeroViajes;
  double the31Calificacion;
  String token;
  String image;

  double? ratingAvg;
  int? ratingCount;


  Driver({
    required this.id,
    required this.rol,
    required this.the01Nombres,
    required this.the02Apellidos,
    required this.the07Celular,
    required this.the14TipoVehiculo,
    required this.the15Marca,
    required this.the16Color,
    required this.the17Modelo,
    required this.the18Placa,
    required this.the19TipoServicio,
    required this.the29FotoPerfil,
    required this.the30NumeroViajes,
    required this.the31Calificacion,
    required this.token,
    required this.image,
    required this.ratingAvg,
    required this.ratingCount,

  });

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json["id"],
    rol: json["rol"],
    the01Nombres: json["01_Nombres"],
    the02Apellidos: json["02_Apellidos"],
    the07Celular: json["07_Celular"],
    the14TipoVehiculo: json["14_Tipo_Vehiculo"],
    the15Marca: json["15_Marca"],
    the16Color: json["16_Color"],
    the17Modelo: json["17_Modelo"],
    the18Placa: json["18_Placa"],
    the19TipoServicio: json["19_Tipo_Servicio"],
    the29FotoPerfil: json["29_Foto_perfil"],
    the30NumeroViajes: json["30_Numero_viajes"],
    the31Calificacion: json["31_Calificacion"]?.toDouble(),
    token: json["token"],
    image: json["image"],
    ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
    ratingCount: (json['rating_count'] as num?)?.toInt(),

  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "rol": rol,
    "01_Nombres": the01Nombres,
    "02_Apellidos": the02Apellidos,
    "07_Celular": the07Celular,
    "14_Tipo_Vehiculo": the14TipoVehiculo,
    "15_Marca": the15Marca,
    "16_Color": the16Color,
    "17_Modelo": the17Modelo,
    "18_Placa": the18Placa,
    "19_Tipo_Servicio": the19TipoServicio,
    "29_Foto_perfil": the29FotoPerfil,
    "30_Numero_viajes": the30NumeroViajes,
    "31_Calificacion": the31Calificacion,
    "token": token,
    "image": image,
    'rating_avg': ratingAvg,
    'rating_count': ratingCount,

  };
}