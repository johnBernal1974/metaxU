import 'package:cloud_firestore/cloud_firestore.dart';

class TravelHistoryIndex {
  final String travelHistoryId; // ✅ referencia al TravelHistory global
  final int numeroViaje;        // ✅ número de viaje
  final String from;
  final String to;
  final double tarifa;
  final Timestamp finalViaje;

  TravelHistoryIndex({
    required this.travelHistoryId,
    required this.numeroViaje,
    required this.from,
    required this.to,
    required this.tarifa,
    required this.finalViaje,
  });

  factory TravelHistoryIndex.fromDoc(String docId, Map<String, dynamic> data) {
    final refId = (data['travelHistoryId'] ??
        data['idTravelHistory'] ??          // ✅ el que tienes en Firestore
        data['travelId'] ??
        docId)
        .toString();

    final numViajeRaw =
        data['numeroViaje'] ?? data['numero_viaje'] ?? data['tripNumber'] ?? 0;
    final numViaje = (numViajeRaw is num)
        ? numViajeRaw.toInt()
        : int.tryParse(numViajeRaw.toString()) ?? 0;

    return TravelHistoryIndex(
      travelHistoryId: refId,
      numeroViaje: numViaje,
      from: (data['from'] ?? '').toString(),
      to: (data['to'] ?? '').toString(),
      tarifa: (data['tarifa'] is num) ? (data['tarifa'] as num).toDouble() : 0.0,
      finalViaje: data['finalViaje'] as Timestamp,
    );
  }

}
