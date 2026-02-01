import 'package:cloud_firestore/cloud_firestore.dart';

class ClientHistoryProvider {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference historyRef(String clientId) {
    return _db.collection('Clients').doc(clientId).collection('history');
  }

  Future<Map<String, dynamic>> getPaginated({
    required String clientId,
    required String yearMonth,
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query query = historyRef(clientId)
        .where('hidden', isEqualTo: false)
        .where('yearMonth', isEqualTo: yearMonth)
        .orderBy('finalViaje', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final QuerySnapshot snap = await query.get();

    return {
      'docs': snap.docs, // 👈 devolvemos docs para mapear afuera
      'lastDoc': snap.docs.isNotEmpty ? snap.docs.last : null,
      'hasMore': snap.docs.length == limit,
    };
  }

  Future<void> hideFromHistory({
    required String clientId,
    required String travelId,
  }) async {
    await historyRef(clientId).doc(travelId).update({
      'hidden': true,
      'hiddenAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> getPaginatedByDateRange({
    required String clientId,
    required DateTime start,
    required DateTime endExclusive,
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query query = historyRef(clientId)
        .where('hidden', isEqualTo: false)
        .where('finalViaje', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('finalViaje', isLessThan: Timestamp.fromDate(endExclusive))
        .orderBy('finalViaje', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snap = await query.get();

    return {
      'docs': snap.docs,
      'lastDoc': snap.docs.isNotEmpty ? snap.docs.last : null,
      'hasMore': snap.docs.length == limit,
    };
  }

}
