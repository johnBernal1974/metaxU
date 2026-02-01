import 'package:cloud_firestore/cloud_firestore.dart';

class TravelHistoryIndex {
  final String id; // travelId
  final String from;
  final String to;
  final double tarifa;
  final Timestamp finalViaje;

  TravelHistoryIndex({
    required this.id,
    required this.from,
    required this.to,
    required this.tarifa,
    required this.finalViaje,
  });

  factory TravelHistoryIndex.fromDoc(String docId, Map<String, dynamic> data) {
    return TravelHistoryIndex(
      id: (data['travelId'] ?? docId).toString(),
      from: (data['from'] ?? '').toString(),
      to: (data['to'] ?? '').toString(),
      tarifa: (data['tarifa'] is num) ? (data['tarifa'] as num).toDouble() : 0.0,
      finalViaje: data['finalViaje'] as Timestamp,
    );
  }
}
