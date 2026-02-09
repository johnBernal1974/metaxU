

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/travel_history_provider.dart';
import '../../../models/travelHistory.dart';

class TravelCalificationController{

  late BuildContext context;
  late Function refresh;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  String? idTravelHistory;
  double? calification;

  late TravelHistoryProvider _travelHistoryProvider;
  TravelHistory? travelHistory;
  late MyAuthProvider _authProvider;


  Future? init (BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    idTravelHistory = ModalRoute.of(context)?.settings.arguments as String;
    _authProvider = MyAuthProvider();
    _travelHistoryProvider = TravelHistoryProvider();
    getTravelHistory ();
  }

  // Future<void> calificate() async {
  //   if (calification == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Por favor selecciona las estrellas con las que quieres calificar al conductor.'),
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //     return;
  //   }
  //   if (calification == 0) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('La calificación mínima es 1.'),
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //     return;
  //   }
  //
  //   // Actualizamos la calificación en el historial de viajes
  //   Map<String, dynamic> data = {
  //     'calificacionAlConductor': calification
  //   };
  //   await _travelHistoryProvider.update(data, idTravelHistory!);
  //   // Obtenemos el ID del cliente que está calificando
  //   String clientId = _authProvider.getUser()!.uid;
  //   // Obtener el historial de viaje para saber quién es el conductor
  //   travelHistory = await _travelHistoryProvider.getById(idTravelHistory!);
  //   if (travelHistory == null) {
  //     if(context.mounted){
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('No se pudo obtener el conductor para calificar.'),
  //           duration: Duration(seconds: 2),
  //         ),
  //       );
  //     }
  //     return;
  //   }
  //
  //   String idConductor = travelHistory!.idDriver; // El ID del conductor
  //
  //   // Crear una subcolección de calificaciones dentro del documento del conductor
  //   Map<String, dynamic> ratingData = {
  //     'idCliente': clientId,
  //     'idTravelHistory': idTravelHistory,
  //     'calificacion': calification,
  //     'fecha': DateTime.now(),
  //   };
  //
  //   // Guardar la calificación en la subcolección "ratings" dentro del conductor
  //   await FirebaseFirestore.instance
  //       .collection('Drivers')  // Asume que la colección de conductores se llama "conductores"
  //       .doc(idConductor)           // El ID del conductor
  //       .collection('ratings')      // La subcolección de calificaciones
  //       .add(ratingData);           // Agregar la calificación
  //
  //   if(context.mounted){
  //     // Redirigir al mapa del cliente
  //     Navigator.pushNamedAndRemoveUntil(
  //       context,
  //       'after_calification_page',
  //           (route) => false,
  //     );
  //   }
  // } 8 feb 2026

  Future<void> calificate() async {
    if (calification == null || calification == 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona al menos 1 estrella.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 1) Lee el travelHistory para saber qué driver es
    travelHistory = await _travelHistoryProvider.getById(idTravelHistory!);
    if (travelHistory == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener el conductor para calificar.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final clientId = _authProvider.getUser()!.uid;
    final idConductor = travelHistory!.idDriver;
    final rating = calification!.toDouble();

    final driverRef = FirebaseFirestore.instance.collection('Drivers').doc(idConductor);
    final ratingRef = driverRef.collection('ratings').doc(); // id automático
    final travelRef = FirebaseFirestore.instance.collection('TravelHistory').doc(idTravelHistory);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // ✅ 1) PRIMERO la lectura
      final driverSnap = await tx.get(driverRef);
      final data = (driverSnap.data() as Map<String, dynamic>?) ?? {};

      final currentAvg = (data['rating_avg'] as num?)?.toDouble() ?? 0.0;
      final currentCount = (data['rating_count'] as num?)?.toInt() ?? 0;

      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + rating) / newCount;

      // ✅ 2) DESPUÉS las escrituras (todas juntas)
      tx.update(travelRef, {'calificacionAlConductor': rating});

      tx.set(ratingRef, {
        'idCliente': clientId,
        'idTravelHistory': idTravelHistory,
        'calificacion': rating,
        'fecha': FieldValue.serverTimestamp(),
      });

      tx.set(driverRef, {
        'rating_avg': newAvg,
        'rating_count': newCount,
      }, SetOptions(merge: true));
    });


    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      'after_calification_page',
          (route) => false,
    );
  }


  void getTravelHistory () async {
    travelHistory = await _travelHistoryProvider.getById(idTravelHistory!);
    refresh();
  }
}

