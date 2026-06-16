import 'package:cloud_firestore/cloud_firestore.dart';

class GeofireProvider {

  final CollectionReference _ref =
  FirebaseFirestore.instance.collection('Locations');

  Stream<List<DocumentSnapshot>> getNearbyDrivers(
      double lat,
      double lng,
      double radius,
      ) {

    return _ref
        .where('status', isEqualTo: 'driver_available')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<DocumentSnapshot> getLocationByIdStream(String id) {
    return _ref.doc(id).snapshots(includeMetadataChanges: true);
  }

  Future<void> delete(String id) {
    return _ref.doc(id).delete();
  }
}