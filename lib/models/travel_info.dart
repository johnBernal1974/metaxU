import 'package:cloud_firestore/cloud_firestore.dart';

class TravelInfo {
  String id;
  String status;
  String idDriver;
  String from;
  String to;
  String idTravelHistory;
  double fromLat;
  double fromLng;
  double toLat;
  double toLng;
  double tarifa;
  double tarifaDescuento;
  double tarifaInicial;
  double distancia;
  double tiempoViaje;
  Timestamp horaSolicitudViaje;
  Timestamp? horaInicioViaje;
  Timestamp? horaFinalizacionViaje;
  String apuntes;

  // 🔥 CLIENTE (standard / VIP)
  String tipoServicio;

  int valorVipExtra;
  String metodoPago;
  String caracteristicaVehiculo;

  // 🔥 VEHÍCULO (REAL)
  String placa;
  String marca;
  String color;
  String tipoVehiculo;

  // 🔥 NUEVO (CLAVE)
  String tipoVehiculoServicio; // Público / Operación nacional

  TravelInfo({
    required this.id,
    required this.status,
    required this.idDriver,
    required this.from,
    required this.to,
    required this.idTravelHistory,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.tarifa,
    required this.tarifaDescuento,
    required this.tarifaInicial,
    required this.distancia,
    required this.tiempoViaje,
    required this.horaSolicitudViaje,
    required this.horaInicioViaje,
    required this.horaFinalizacionViaje,
    required this.apuntes,

    // cliente
    required this.tipoServicio,
    required this.valorVipExtra,
    required this.metodoPago,
    required this.caracteristicaVehiculo,

    // vehículo
    required this.placa,
    required this.marca,
    required this.color,
    required this.tipoVehiculo,
    required this.tipoVehiculoServicio,
  });

  factory TravelInfo.fromJson(Map<String, dynamic> json) => TravelInfo(
    id: json["id"],
    status: json["status"],
    idDriver: json["idDriver"],
    from: json["from"],
    to: json["to"],
    idTravelHistory: json["idTravelHistory"],
    fromLat: json["fromLat"]?.toDouble() ?? 0.0,
    fromLng: json["fromLng"]?.toDouble() ?? 0.0,
    toLat: json["toLat"]?.toDouble() ?? 0.0,
    toLng: json["toLng"]?.toDouble() ?? 0.0,
    tarifa: json["tarifa"]?.toDouble() ?? 0.0,
    tarifaDescuento: json["tarifaDescuento"]?.toDouble() ?? 0.0,
    tarifaInicial: json["tarifaInicial"]?.toDouble() ?? 0.0,
    distancia: json["distancia"]?.toDouble() ?? 0.0,
    tiempoViaje: json["tiempoViaje"]?.toDouble() ?? 0.0,
    horaSolicitudViaje: json["horaSolicitudViaje"],
    horaInicioViaje: json["horaInicioViaje"],
    horaFinalizacionViaje: json["horaFinalizacionViaje"],
    apuntes: json["apuntes"],

    // 🔥 CLIENTE
    tipoServicio: json["tipo_servicio"] ?? 'standard',
    valorVipExtra: json["valor_vip_extra"] ?? 0,
    metodoPago: json["metodo_pago"] ?? 'Efectivo',
    caracteristicaVehiculo: json["caracteristica_vehiculo"] ?? '',

    // 🔥 VEHÍCULO
    placa: json["placa"] ?? '',
    marca: json["marca"] ?? '',
    color: json["color"] ?? '',
    tipoVehiculo: json["tipoVehiculo"] ?? '',

    // 🔥 NUEVO
    tipoVehiculoServicio: json["tipoVehiculoServicio"] ?? '',
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "status": status,
    "idDriver": idDriver,
    "from": from,
    "to": to,
    "idTravelHistory": idTravelHistory,
    "fromLat": fromLat,
    "fromLng": fromLng,
    "toLat": toLat,
    "toLng": toLng,
    "tarifa": tarifa,
    "tarifaDescuento": tarifaDescuento,
    "tarifaInicial": tarifaInicial,
    "distancia": distancia,
    "tiempoViaje": tiempoViaje,
    "horaSolicitudViaje": horaSolicitudViaje,
    "horaInicioViaje": horaInicioViaje,
    "horaFinalizacionViaje": horaFinalizacionViaje,
    "apuntes": apuntes,

    // 🔥 CLIENTE
    "tipo_servicio": tipoServicio,
    "valor_vip_extra": valorVipExtra,
    "metodo_pago": metodoPago,
    "caracteristica_vehiculo": caracteristicaVehiculo,

    // 🔥 VEHÍCULO
    "placa": placa,
    "marca": marca,
    "color": color,
    "tipoVehiculo": tipoVehiculo,
    "tipoVehiculoServicio": tipoVehiculoServicio,
  };
}