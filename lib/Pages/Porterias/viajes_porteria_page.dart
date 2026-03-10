import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

class ViajesPorteriaPage extends StatefulWidget {
  const ViajesPorteriaPage({super.key});

  @override
  State<ViajesPorteriaPage> createState() => _ViajesPorteriaPageState();
}

class _ViajesPorteriaPageState extends State<ViajesPorteriaPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final AudioPlayer _player = AudioPlayer();

  /// evitar repetir sonido muchas veces
  final Set<String> taxisNotificados = {};

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
        title: const Text("Viajes activos"),
      ),

      body: StreamBuilder<QuerySnapshot>(
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

            return status == "created" ||
                status == "accepted" ||
                status == "driver_on_the_way" ||
                status == "driver_is_waiting";

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

              /// reproducir sonido cuando el taxi llega
              if (status == "driver_is_waiting" && !taxisNotificados.contains(requestId)) {

                taxisNotificados.add(requestId);

                _reproducirTaxiLlegada();

                _vibrarTaxiLlegado();

              }

              return _cardSolicitud(context, data);
            },
          );
        },
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setAsset("assets/audio/tu_taxi_ha_llegado.mp3");
    } catch (e) {
      debugPrint("Error cargando sonido: $e");
    }
  }

  Future<void> _vibrarTaxiLlegado() async {

    if (await Vibration.hasVibrator() ?? false) {

      Vibration.vibrate(
        duration: 600,
        amplitude: 128,
      );

    }

  }

  Future<void> _reproducirTaxiLlegada() async {
    try {

      await _player.stop();

      await _player.setAsset("assets/audio/tu_taxi_ha_llegado.mp3");

      await _player.play();

    } catch (e) {
      debugPrint("Error reproduciendo sonido: $e");
    }
  }

  Widget _cardSolicitud(BuildContext context, Map<String, dynamic> data) {

    final usuario = data["usuario"] ?? "";
    final apto = data["apto"] ?? "";
    final status = data["status"] ?? "created";

    final bool taxiLlego = status == "driver_is_waiting";

    final conductor = data["nombreConductor"] ?? "";
    final placa = data["placa"] ?? "";
    final celular = data["celularConductor"] ?? "";

    /// estado del viaje
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

    /// color de fondo animado
    Color backgroundColor = Colors.white;

    if (status == "driver_is_waiting") {
      backgroundColor = Colors.green.withOpacity(0.12);
    }

    /// fecha
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
        color: taxiLlego
            ? Colors.green.withOpacity(0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: taxiLlego
                ? Colors.green.withOpacity(0.35)
                : Colors.black.withOpacity(0.08),
            blurRadius: taxiLlego ? 24 : 6,
            spreadRadius: taxiLlego ? 2 : 0,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// fila principal
            Row(
              children: [

                Image.asset(
                  "assets/imagen_taxi.png",
                  height: 32,
                ),

                SizedBox(width: 10.r),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        usuario,
                        style: TextStyle(
                          fontSize: 15.r,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      if (apto.isNotEmpty)
                        Text(
                          "Apto: $apto",
                          style: TextStyle(
                            fontSize: 12.r,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                      SizedBox(height: 3.r),

                      Text(
                        fechaHora,
                        style: TextStyle(
                          fontSize: 10.r,
                          color: Colors.black54,
                        ),
                      ),

                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 10.r),

            /// estado del viaje
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 5.r),
              decoration: BoxDecoration(
                color: colorEstado.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                textoEstado,
                style: TextStyle(
                  fontSize: 12.r,
                  fontWeight: FontWeight.w800,
                  color: colorEstado,
                ),
              ),
            ),

            /// datos del conductor
            if (conductor.isNotEmpty) ...[

              SizedBox(height: 10.r),
              Divider(),
              SizedBox(height: 5.r),

              Row(
                children: [
                  const Icon(Icons.person, size: 18),
                  SizedBox(width: 6.r),
                  Expanded(
                    child: Text(
                      conductor,
                      style: TextStyle(
                        fontSize: 13.r,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 6.r),

              Row(
                children: [
                  const Icon(Icons.directions_car, size: 18),
                  SizedBox(width: 6.r),
                  Text(
                    "Placa: $placa",
                    style: TextStyle(
                      fontSize: 13.r,
                    ),
                  ),
                ],
              ),

              if (celular.isNotEmpty) ...[

                SizedBox(height: 10.r),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.r,
                        vertical: 6.r,
                      ),
                    ),
                    onPressed: () {
                      _verDatosConductor(context, data);
                    },
                    icon: const Icon(
                      Icons.phone,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      "Llamar",
                      style: TextStyle(
                        fontSize: 12.r,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              ],
            ],

          ],
        ),
      ),
    );
  }

  void _verDatosConductor(BuildContext context, Map<String, dynamic> data) {

    final placa = data["placa"] ?? "No asignado";
    final conductor = data["nombreConductor"] ?? "Sin conductor";
    final celular = data["celularConductor"] ?? "No disponible";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(18),
        ),
      ),
      builder: (context) {

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              /// indicador visual
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Conductor asignado",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 20),

              /// conductor
              Row(
                children: [
                  const Icon(Icons.person),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      conductor,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// placa
              Row(
                children: [
                  const Icon(Icons.directions_car),
                  const SizedBox(width: 10),
                  Text(
                    "Placa: $placa",
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// celular
              Row(
                children: [
                  const Icon(Icons.phone),
                  const SizedBox(width: 10),
                  Text(
                    celular,
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

            ],
          ),
        );

      },
    );
  }
}