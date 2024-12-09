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
  int theTiempoDeBloqueo;
  double theValorKmRegular;
  double theValorMinRegular;
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
    required this.theTiempoDeBloqueo,
    required this.theValorKmRegular,
    required this.theValorMinRegular,
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
    theTiempoDeBloqueo: json["tiempo_de_bloqueo"]  ?? '',
    theValorKmRegular: json["valor_km_regular"]?.toDouble() ?? 0.0,
    theValorMinRegular: json["valor_min_regular"]?.toDouble() ?? 0.0,
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
    "tiempo_de_bloqueo": theTiempoDeBloqueo,
    "valor_km_regular": theValorKmRegular,
    "valor_min_regular": theValorMinRegular,
    "dinamica": theDinamica,
    "link_descarga_client": theLinkDescargaClient,
    "link_descarga_driver": theLinkDescargaDriver,
  };
}
