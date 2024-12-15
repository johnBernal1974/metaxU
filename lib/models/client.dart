
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

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
  Timestamp the21FechaDeRegistro;
  String token;
  String image;
  String status;
  bool the00isTraveling;
  int the22Cancelaciones;
  bool the41SuspendidoPorCancelaciones;
  bool fotoPerfilTomada;


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

  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json["id"] ?? '',
    the01Nombres: json["01_Nombres"]  ?? '',
    the02Apellidos: json["02_Apellidos"]  ?? '',
    the06Email: json["06_Email"]  ?? '',
    the07Celular: json["07_Celular"]  ?? '',
    the09Genero: json["09_Genero"]  ?? '',
    the15FotoPerfilUsuario: json["15_Foto_perfil_usuario"]  ?? '',
    the17Bono: json["17_Bono"]  ?? '',
    the18Calificacion: json["18_Calificacion"]?.toDouble()  ?? '',
    the19Viajes: json["19_Viajes"]  ?? '',
    the20Rol: json["20_Rol"]  ?? '',
    the21FechaDeRegistro: json["21_Fecha_de_registro"]  ?? '',
    token: json["token"]  ?? '',
    image: json["image"]  ?? '',
    status: json["status"]  ?? '',
    the00isTraveling: json["00_is_traveling"]  ?? '',
    the22Cancelaciones: json["22_cancelaciones"]  ?? '',
    the41SuspendidoPorCancelaciones: json["41_Suspendido_Por_Cancelaciones"]  ?? '',
    fotoPerfilTomada: json["foto_perfil_tomada"]  ?? '',
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "01_Nombres": the01Nombres,
    "02_Apellidos": the02Apellidos,
    "06_Email": the06Email,
    "07_Celular": the07Celular,
    "09_Genero": the09Genero,
    "15_Foto_perfil_usuario": the15FotoPerfilUsuario,
    "17_Bono": the17Bono,
    "18_Calificacion": the18Calificacion,
    "19_Viajes": the19Viajes,
    "20_Rol": the20Rol,
    "21_Fecha_de_registro": the21FechaDeRegistro,
    "token": token,
    "image": image,
    "status": status,
    "00_is_traveling": the00isTraveling,
    "22_cancelaciones": the22Cancelaciones,
    "41_Suspendido_Por_Cancelaciones": the41SuspendidoPorCancelaciones,
    "foto_perfil_tomada": fotoPerfilTomada,
  };
}
