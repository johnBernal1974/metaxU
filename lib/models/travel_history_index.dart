import 'package:cloud_firestore/cloud_firestore.dart';

class TravelHistoryIndex {
  final String travelHistoryId;
  final String numeroViaje; // ✅ siempre String
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
        data['idTravelHistory'] ??
        data['travelId'] ??
        docId)
        .toString();

    // ✅ Siempre String (aunque venga int/num en docs viejos)
    final numeroViaje = (data['numeroViaje'] ??
        data['numero_viaje'] ??
        data['tripNumber'] ??
        '')
        .toString();

    // ✅ finalViaje: evitar cast directo si viene null o tipo raro
    final Timestamp finalViaje = data['finalViaje'] is Timestamp
        ? data['finalViaje'] as Timestamp
        : Timestamp.now();

    return TravelHistoryIndex(
      travelHistoryId: refId,
      numeroViaje: numeroViaje,
      from: (data['from'] ?? '').toString(),
      to: (data['to'] ?? '').toString(),
      tarifa: (data['tarifa'] is num) ? (data['tarifa'] as num).toDouble() : 0.0,
      finalViaje: finalViaje,
    );
  }
}
