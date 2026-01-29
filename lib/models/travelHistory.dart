
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

TravelHistory travelHistoryFromJson(String str) => TravelHistory.fromJson(json.decode(str));

String travelHistoryToJson(TravelHistory data) => json.encode(data.toJson());

class TravelHistory {
  String id;
  String idClient;
  String idDriver;
  String from;
  String to;
  String nameDriver;
  String apellidosDriver;
  String placaShow;
  String placaNorm;
  Timestamp? solicitudViaje;
  Timestamp? inicioViaje;
  Timestamp? finalViaje;
  double tarifa;
  double tarifaDescuento;
  double tarifaInicial;
  double calificacionAlConductor;
  double calificacionAlCliente;

  TravelHistory({
    required this.id,
    required this.idClient,
    required this.idDriver,
    required this.from,
    required this.to,
    required this.nameDriver,
    required this.apellidosDriver,
    required this.placaShow,
    required this.placaNorm,
    required this.solicitudViaje,
    required this.inicioViaje,
    required this.finalViaje,
    required this.tarifa,
    required this.tarifaDescuento,
    required this.tarifaInicial,
    required this.calificacionAlConductor,
    required this.calificacionAlCliente,
  });

  factory TravelHistory.fromJson(Map<String, dynamic> json) => TravelHistory(
    id: (json["id"] ?? "") as String,
    idClient: (json["idClient"] ?? "") as String,
    idDriver: (json["idDriver"] ?? "") as String,
    from: (json["from"] ?? "") as String,
    to: (json["to"] ?? "") as String,

    // ✅ estos dos eran los null
    nameDriver: (json["nameDriver"] ?? "") as String,
    apellidosDriver: (json["apellidosDriver"] ?? "") as String,

    placaShow: (json["placaShow"] ?? json["placa"] ?? "") as String,
    placaNorm: (json["placaNorm"] ??
        ((json["placaShow"] ?? json["placa"] ?? "") as String)
            .replaceAll("-", "")) as String,

    solicitudViaje: json["solicitudViaje"] as Timestamp?,
    inicioViaje: json["inicioViaje"] as Timestamp?,
    finalViaje: json["finalViaje"] as Timestamp?,

    tarifa: (json["tarifa"] ?? 0).toDouble(),
    tarifaDescuento: (json["tarifaDescuento"] ?? 0).toDouble(),
    tarifaInicial: (json["tarifaInicial"] ?? 0).toDouble(),
    calificacionAlConductor: (json["calificacionAlConductor"] ?? 0).toDouble(),
    calificacionAlCliente: (json["calificacionAlCliente"] ?? 0).toDouble(),
  );


  Map<String, dynamic> toJson() => {
    "id": id,
    "idClient": idClient,
    "idDriver": idDriver,
    "from": from,
    "to": to,
    // "nameDriver": nameDriver,
    // "apellidosDriver": apellidosDriver,
    "placaShow": placaShow,
    "placaNorm": placaNorm,
    "solicitudViaje": solicitudViaje,
    "inicioViaje": inicioViaje,
    "finalViaje": finalViaje,
    "tarifa": tarifa,
    "tarifaDescuento": tarifaDescuento,
    "tarifaInicial": tarifaInicial,
    "calificacionAlConductor": calificacionAlConductor,
    "calificacionAlCliente": calificacionAlCliente,
  };
}