import 'package:cloud_firestore/cloud_firestore.dart';

class TravelHistoryIndex {

  final String travelHistoryId;

  final String numeroViaje;

  final String from;

  final String to;

  final double tarifa;

  final double tarifaInicial;

  final double tarifaDescuento;

  final double totalClientePaga;

  final bool bonoPagado;

  final Timestamp finalViaje;

  TravelHistoryIndex({

    required this.travelHistoryId,

    required this.numeroViaje,

    required this.from,

    required this.to,

    required this.tarifa,

    required this.tarifaInicial,

    required this.tarifaDescuento,

    required this.totalClientePaga,

    required this.bonoPagado,

    required this.finalViaje,
  });

  factory TravelHistoryIndex.fromDoc(

      String docId,

      Map<String, dynamic> data,
      ) {

    final refId =

    (data['travelHistoryId'] ??

        data['idTravelHistory'] ??

        data['travelId'] ??

        docId)
        .toString();

    final numeroViaje =

    (data['numeroViaje'] ??

        data['numero_viaje'] ??

        data['tripNumber'] ??

        '')
        .toString();

    final Timestamp finalViaje =

    data['finalViaje'] is Timestamp

        ? data['finalViaje']
    as Timestamp

        : Timestamp.now();

    final tarifa =

    (data['tarifa'] is num)

        ? (data['tarifa'] as num)
        .toDouble()

        : 0.0;

    final tarifaInicial =

    (data['tarifaInicial'] is num)

        ? (data['tarifaInicial'] as num)
        .toDouble()

        : tarifa;

    final tarifaDescuento =

    (data['tarifaDescuento'] is num)

        ? (data['tarifaDescuento']
    as num)
        .toDouble()

        : 0.0;

    final totalClientePaga =

    (data['totalClientePaga']
    is num)

        ? (data['totalClientePaga']
    as num)
        .toDouble()

        : tarifa;

    final bonoPagado =
        data['bonoPagado'] == true;

    return TravelHistoryIndex(

      travelHistoryId: refId,

      numeroViaje: numeroViaje,

      from:
      (data['from'] ?? '')
          .toString(),

      to:
      (data['to'] ?? '')
          .toString(),

      tarifa: tarifa,

      tarifaInicial:
      tarifaInicial,

      tarifaDescuento:
      tarifaDescuento,

      totalClientePaga:
      totalClientePaga,

      bonoPagado:
      bonoPagado,

      finalViaje: finalViaje,
    );
  }
}
