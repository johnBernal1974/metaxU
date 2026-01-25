// To parse this JSON data, do
//
//     final price = priceFromJson(jsonString);

import 'dart:convert';

Price priceFromJson(String str) => Price.fromJson(json.decode(str));

String priceToJson(Price data) => json.encode(data.toJson());

class Price {
  String theCorreoUsuarios;
  String theCelularAtencionUsuarios;
  String theLinkCancelarCuenta;
  String theLinkPoliticasPrivacidad;
  String theMantenimientoUsuarios;
  int theDistanciaTarifaMinima;
  int theNumeroCancelacionesUsuario;
  double theRadioDeBusqueda;
  int theTarifaAeropuerto;
  int theTarifaMinimaRegular;
  //nuevas
  int theTarifaMinimaHotel;
  int theTarifaMinimaTurismo;

  int theTiempoDeBloqueo;
  double theValorKmRegular;
  double theValorMinRegular;

  double theValorKmHotel;
  double theValorMinHotel;

  double theValorKmTurismo;
  double theValorMinTurismo;

  double theDinamica;
  String theLinkDescargaClient;
  String theLinkDescargaDriver;


  Price({

    required this.theCorreoUsuarios,
    required this.theCelularAtencionUsuarios,
    required this.theLinkCancelarCuenta,
    required this.theLinkPoliticasPrivacidad,
    required this.theMantenimientoUsuarios,
    required this.theDistanciaTarifaMinima,
    required this.theNumeroCancelacionesUsuario,
    required this.theRadioDeBusqueda,
    required this.theTarifaAeropuerto,
    required this.theTarifaMinimaRegular,
    required this.theTarifaMinimaHotel,
    required this.theTarifaMinimaTurismo,
    required this.theTiempoDeBloqueo,
    required this.theValorKmRegular,
    required this.theValorMinRegular,
    required this.theValorKmHotel,
    required this.theValorMinHotel,
    required this.theValorKmTurismo,
    required this.theValorMinTurismo,
    required this.theDinamica,
    required this.theLinkDescargaClient,
    required this.theLinkDescargaDriver,


  });

  factory Price.fromJson(Map<String, dynamic> json) => Price(
    theCorreoUsuarios: json["correo_usuarios"]  ?? '',
    theCelularAtencionUsuarios: json["celular_atencion_usuarios"]  ?? '',
    theLinkCancelarCuenta: json["link_cancelar_cuenta"]  ?? '',
    theLinkPoliticasPrivacidad: json["link_politicas_privacidad"]  ?? '',
    theMantenimientoUsuarios: json["mantenimiento_usuarios"]  ?? '',
    theDistanciaTarifaMinima: json["distancia_tarifa_minima"]  ?? '',
    theNumeroCancelacionesUsuario: json["numero_cancelaciones_usuario"]  ?? '',
    theRadioDeBusqueda: json["radio_de_busqueda"]?.toDouble() ?? 0.0,
    theTarifaAeropuerto: json["tarifa_aeropuerto"]  ?? '',
    theTarifaMinimaRegular: json["tarifa_minima_regular"]?? '',
    theTarifaMinimaHotel: json["tarifa_minima_hotel"]?? '',
    theTarifaMinimaTurismo: json["tarifa_minima_turismo"]?? '',
    theTiempoDeBloqueo: json["tiempo_de_bloqueo"]  ?? '',

    theValorKmRegular: (json["valor_km_regular"] ?? 0).toDouble(),
    theValorMinRegular: (json["valor_min_regular"] ?? 0).toDouble(),

    theValorKmHotel: (json["valor_km_hotel"] ?? 0).toDouble(),
    theValorMinHotel: (json["valor_min_hotel"] ?? 0).toDouble(),

    theValorKmTurismo: (json["valor_km_turismo"] ?? 0).toDouble(),
    theValorMinTurismo: (json["valor_min_turismo"] ?? 0).toDouble(),


    theDinamica: json["dinamica"]?.toDouble() ?? 0.0,
    theLinkDescargaClient: json["link_descarga_client"]?? '',
    theLinkDescargaDriver: json["link_descarga_driver"]?? '',

  );

  Map<String, dynamic> toJson() => {
    "correo_usuarios": theCorreoUsuarios,
    "celular_atencion_usuarios": theCelularAtencionUsuarios,
    "link_cancelar_cuenta": theLinkCancelarCuenta,
    "link_politicas_privacidad": theLinkPoliticasPrivacidad,
    "mantenimiento_usuarios": theMantenimientoUsuarios,
    "distancia_tarifa_minima": theDistanciaTarifaMinima,
    "numero_cancelaciones_usuario": theNumeroCancelacionesUsuario,
    "radio_de_busqueda": theRadioDeBusqueda,
    "tarifa_aeropuerto": theTarifaAeropuerto,
    "tarifa_minima_regular": theTarifaMinimaRegular,
    "tarifa_minima_hotel": theTarifaMinimaHotel,
    "tarifa_minima_turismo": theTarifaMinimaTurismo,
    "tiempo_de_bloqueo": theTiempoDeBloqueo,
    "valor_km_regular": theValorKmRegular,
    "valor_min_regular": theValorMinRegular,

    "valor_km_hotel": theValorKmHotel,
    "valor_min_hotel": theValorMinHotel,

    "valor_km_turismo": theValorKmTurismo,
    "valor_min_turismo": theValorMinTurismo,

    "dinamica": theDinamica,
    "link_descarga_client": theLinkDescargaClient,
    "link_descarga_driver": theLinkDescargaDriver,
  };
}
