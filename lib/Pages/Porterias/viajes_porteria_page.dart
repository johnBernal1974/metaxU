import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../helpers/sound_manager.dart';
import '../../src/colors/colors.dart';

class ViajesPorteriaPage extends StatefulWidget {
  const ViajesPorteriaPage({super.key});

  @override
  State<ViajesPorteriaPage> createState() => _ViajesPorteriaPageState();
}

class _ViajesPorteriaPageState extends State<ViajesPorteriaPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SoundManager _sound = SoundManager();

  @override
  Widget build(BuildContext context) {

    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("Usuario no válido")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary.withOpacity(0.7),
        title: const Text("Viajes activos", style: TextStyle(
          fontWeight: FontWeight.w700
        ),),
      ),

      body: Column(
        children: [

          /// BOTON NUEVO SERVICIO
          Padding(
            padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 6.r),
            child: SizedBox(
              width: double.infinity,
              height: 40.r,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text(
                  "Solicitar nuevo servicio",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    "home_porteria",
                        (route) => false,
                  );
                },
              ),
            ),
          ),

          /// LISTA DE VIAJES
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection("TravelRequests")
                  .where("porteriaId", isEqualTo: uid)
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {

                  final data = doc.data() as Map<String, dynamic>;
                  final status = data["status"];

                  final subStatus = data["subStatus"];

                  if (subStatus == "desistido") {
                    return false;
                  }

                  final Timestamp? cancelledAt = data["cancelledAt"];

                  if (status == "cancelledByPorteria" && cancelledAt != null) {

                    final diff = DateTime.now().difference(cancelledAt.toDate()).inSeconds;

                    /// si ya pasaron 4 segundos no se muestra
                    if (diff > 4) {
                      return false;
                    }
                  }

                  return status == "created" ||
                      status == "accepted" ||
                      status == "driver_on_the_way" ||
                      status == "driver_is_waiting" ||
                      status == "no_driver_found" ||
                      status == "cancelledByPorteria" ||
                      status == "cancelByDriverAfterAccepted" ||
                      status == "cancelTimeIsOver";

                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text("No hay viajes activos"),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.all(16.r),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {

                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final requestId = doc.id;
                    final status = data["status"];

                    final notifiedTaxiWaiting = data["notifiedTaxiWaiting"] ?? false;

                    if (status == "driver_is_waiting" && !notifiedTaxiWaiting) {

                      Future.microtask(() async {

                        await _sound.playTaxiLlegada();
                        await _vibrarTaxiLlegado();

                        _firestore
                            .collection("TravelRequests")
                            .doc(requestId)
                            .update({
                          "notifiedTaxiWaiting": true
                        });

                      });

                    }

                    final notifiedDriverCancel = data["notifiedDriverCancel"] ?? false;

                    if (status == "cancelByDriverAfterAccepted" && !notifiedDriverCancel) {

                      Future.microtask(() async {

                        await _sound.playCancelacionConductor();

                        _firestore
                            .collection("TravelRequests")
                            .doc(requestId)
                            .update({
                          "notifiedDriverCancel": true
                        });

                      });

                    }

                    final notifiedTimeOver = data["notifiedTimeOver"] ?? false;

                    if (status == "cancelTimeIsOver" && !notifiedTimeOver) {

                      Future.microtask(() async {

                        await _sound.playCancelacionConductor();

                        _firestore
                            .collection("TravelRequests")
                            .doc(requestId)
                            .update({
                          "notifiedTimeOver": true
                        });

                      });

                    }

                    return _cardSolicitud(context, requestId, data);
                  },
                );
              },
            ),
          ),

        ],
      ),
    );
  }
  @override
  void initState() {
    super.initState();
  }

  Future<void> _llamarConductor(String telefono) async {

    final Uri uri = Uri(
      scheme: 'tel',
      path: telefono,
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

  }

  String _formatearPlaca(String placa) {

    if (placa.length == 6) {
      return "${placa.substring(0,3)}-${placa.substring(3)}";
    }

    return placa;

  }

  Future<void> _vibrarTaxiLlegado() async {

    if (await Vibration.hasVibrator() ?? false) {

      Vibration.vibrate(
        duration: 600,
        amplitude: 128,
      );

    }

  }


  Widget _cardSolicitud(BuildContext context, String requestId, Map<String, dynamic> data) {

    if (
    data["subStatus"] == "desistido" &&
        (
            data["status"] == "cancelByDriverAfterAccepted" ||
                data["status"] == "cancelTimeIsOver"
        )
    ) {
      return const SizedBox();
    }

    final usuario = data["usuario"] ?? "";
    final apto = data["apto"] ?? "";
    final status = data["status"] ?? "created";

    final bool taxiLlego = status == "driver_is_waiting";
    final bool canceladoPorConductor = status == "cancelByDriverAfterAccepted";

    final conductor = data["nombreConductor"] ?? "";
    final placa = data["placa"] ?? "";
    final celular = data["celularConductor"] ?? "";

    String textoEstado = "Buscando conductor";
    Color colorEstado = Colors.orange;

    if (status == "accepted") {
      textoEstado = "Viaje aceptado";
      colorEstado = Colors.green;
    }

    if (status == "driver_on_the_way") {
      textoEstado = "Taxi en camino";
      colorEstado = Colors.blue;
    }

    if (status == "driver_is_waiting") {
      textoEstado = "El taxi ha llegado";
      colorEstado = Colors.black87;
    }

    if (status == "no_driver_found") {
      textoEstado = "No aceptado";
      colorEstado = Colors.red;
    }

    if (status == "cancelledByPorteria") {
      textoEstado = "Viaje cancelado";
      colorEstado = Colors.grey;
    }

    if (status == "cancelByDriverAfterAccepted") {
      textoEstado = "Cancelado por conductor";
      colorEstado = Colors.red;
    }

    if (status == "cancelTimeIsOver") {
      textoEstado = "Cancelado por tiempo de espera";
      colorEstado = Colors.red;
    }

    final Timestamp? ts = data["timestamp"];
    String fechaHora = "";

    if (ts != null) {
      final date = ts.toDate();
      fechaHora = DateFormat('dd/MM/yyyy hh:mm a').format(date);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: EdgeInsets.only(bottom: 12.r),
      decoration: BoxDecoration(
        color: canceladoPorConductor
            ? Colors.white70
            : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: canceladoPorConductor
              ? Colors.red
              : taxiLlego
              ? Colors.green
              : Colors.black.withOpacity(0.08),
          width: canceladoPorConductor || taxiLlego ? 1 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6.r),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Center(
                child: Text(
                  textoEstado,
                  style: TextStyle(
                    fontSize: 15.r,
                    fontWeight: FontWeight.w900,
                    color: colorEstado,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),

            /// USUARIO + APTO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  usuario,
                  style: TextStyle(
                    fontSize: 13.r,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (apto.isNotEmpty)
                  Text(
                    "Apto: $apto",
                    style: TextStyle(
                      fontSize: 13.r,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            /// FECHA
            Text(
              fechaHora,
              style: TextStyle(
                  fontSize: 10.r,
                  color: Colors.black,
                  fontWeight: FontWeight.w400
              ),
            ),

            /// BOTONES
            if (status == "no_driver_found" ||
                status == "cancelByDriverAfterAccepted" ||
                status == "cancelTimeIsOver") ...[

              SizedBox(height: 12.r),

              Row(
                children: [

                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 8.r),
                      ),
                      onPressed: () {
                        _volverASolicitar(requestId, data);
                      },
                      child: Text(
                        "Reintentar",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12.r,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 8.r),

                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black54, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 8.r),
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection("TravelRequests")
                            .doc(requestId)
                            .update({
                          "subStatus": "desistido",
                          "desistidoAt": FieldValue.serverTimestamp(),
                        });
                      },
                      child: Text(
                        "Desistir",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12.r,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ],

            /// DIVIDER
            if (
            conductor.isNotEmpty &&
                status != "cancelByDriverAfterAccepted" &&
                status != "cancelTimeIsOver" &&
                status != "cancelledByPorteria"
            ) ...[
              SizedBox(height: 12.r),

              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: gris.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    /// TAXI
                    Image.asset(
                      "assets/imagen_taxi.png",
                      height: 25,
                    ),

                    SizedBox(width: 2.r),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Text(
                            conductor,
                            style: TextStyle(
                                fontSize: 12.r,
                                fontWeight: FontWeight.w700,
                                height: 1.1
                            ),
                          ),

                          SizedBox(height: 6.r),

                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.r,
                              vertical: 2.r,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatearPlaca(placa),
                              style: TextStyle(
                                fontSize: 11.r,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// ICONOS DERECHA
                    Column(
                      children: [

                        if (celular.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.black),
                            onPressed: () {
                              _llamarConductor(celular);
                            },
                          ),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 6.r),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                          ),
                          onPressed: () async {

                            final confirmar = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  title: const Text(
                                    "Cancelar servicio",
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  content: const Text(
                                    "¿Estás seguro de cancelar este servicio?",
                                  ),
                                  actions: [

                                    TextButton(
                                      child: const Text("No"),
                                      onPressed: () {
                                        Navigator.pop(context, false);
                                      },
                                    ),

                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text(
                                        "Sí, cancelar",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context, true);
                                      },
                                    ),

                                  ],
                                );
                              },
                            );

                            if (confirmar == true) {
                              await _cancelarSolicitud(requestId);
                            }

                          },
                          child: Text(
                            "Cancelar viaje",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.r,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ]

          ],
        ),
      ),
    );
  }

  Future<void> _cancelarSolicitud(String requestId) async {

    final firestore = FirebaseFirestore.instance;

    final batch = firestore.batch();

    final requestRef = firestore.collection("TravelRequests").doc(requestId);
    final travelInfoRef = firestore.collection("TravelInfo").doc(requestId);

    batch.update(requestRef, {
      "status": "cancelledByPorteria",
      "cancelledAt": FieldValue.serverTimestamp(),
    });

    batch.update(travelInfoRef, {
      "status": "cancelledByPorteria",
    });

    await batch.commit();

  }

  Future<void> _volverASolicitar(String requestId, Map<String, dynamic> data) async {

    await FirebaseFirestore.instance
        .collection("TravelRequests")
        .doc(requestId)
        .delete();

    await FirebaseFirestore.instance
        .collection("TravelInfo")
        .doc(requestId)
        .delete();

    if (context.mounted) {

      Navigator.pushNamedAndRemoveUntil(
        context,
        "home_porteria",
            (route) => false,
        arguments: {
          "usuario": data["usuario"],
          "apto": data["apto"],
          "metodoPago": data["metodoPago"],
          "caracteristica": data["caracteristica"],
          "autoSolicitar": true,
        },
      );
    }
  }
}