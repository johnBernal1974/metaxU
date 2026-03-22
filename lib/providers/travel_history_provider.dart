

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver.dart';
import 'driver_provider.dart';
import 'package:apptaxis/models/travelHistory.dart';

class TravelHistoryProvider{

  late CollectionReference _ref;
  TravelHistory? travelHistory;

  TravelHistoryProvider (){
    _ref = FirebaseFirestore.instance.collection('TravelHistory');
  }

  Future<String> create(TravelHistory travelHistory) async {
    String errorMessage;

    try{
      String id = _ref.doc().id;
      travelHistory.id = id;
      await _ref.doc(travelHistory.id).set(travelHistory.toJson());// almacenamos el id
      return id;
    }on FirebaseFirestore catch(error){
      errorMessage = error.hashCode as String;
    }

    return Future.error(errorMessage);

  }


  Stream<DocumentSnapshot> getByIdStream(String id) {
    return _ref.doc(id).snapshots(includeMetadataChanges: true);
  }

  Future<TravelHistory?> getById(String id) async {
    DocumentSnapshot document = await _ref.doc(id).get();
    if(document.exists){
      TravelHistory? travelHistory= TravelHistory.fromJson(document.data() as Map<String, dynamic>);
      return travelHistory;
    }
    else{
      return null;
    }

  }

  Future<void> update(Map<String, dynamic> data, String id) {
    return _ref.doc(id).update(data);
  }

  Future<void> delete(String id){
    return _ref.doc(id).delete();
  }

  Future<List<TravelHistory>> getByIdClient(String idClient) async {
    QuerySnapshot querySnapshot = await _ref
        .where('idClient', isEqualTo: idClient)
        .orderBy('finalViaje', descending: true)
        .get();

    List<TravelHistory> travelHistoryList = [];

    for (DocumentSnapshot doc in querySnapshot.docs) {
      if (doc.data() != null) {
        travelHistoryList.add(
          TravelHistory.fromJson(doc.data() as Map<String, dynamic>),
        );
      }
    }

    // 🔥 CACHE DE DRIVERS
    Map<String, Driver> driverCache = {};
    DriverProvider driverProvider = DriverProvider();

    for (TravelHistory travelHistory in travelHistoryList) {
      String idDriver = travelHistory.idDriver;

      if (!driverCache.containsKey(idDriver)) {
        Driver? driver = await driverProvider.getById(idDriver);
        if (driver != null) {
          driverCache[idDriver] = driver;
        }
      }

      final driver = driverCache[idDriver];

      travelHistory.nameDriver = driver?.the01Nombres ?? '';
      travelHistory.apellidosDriver = driver?.the02Apellidos ?? '';
    }

    return travelHistoryList;
  }

}