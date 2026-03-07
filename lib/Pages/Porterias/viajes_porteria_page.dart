import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class ViajesPorteriaPage extends StatelessWidget {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

              final data = docs[index].data() as Map<String, dynamic>;

              return _cardSolicitud(context, data);
            },
          );
        },
      ),
    );
  }

  Widget _cardSolicitud(BuildContext context, Map<String, dynamic> data) {

    final usuario = data["usuario"] ?? "";
    final apto = data["apto"] ?? "";
    final status = data["status"] ?? "created";

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
      textoEstado = "El Taxi ha llegado";
      colorEstado = Colors.black54;
    }

    final Timestamp? ts = data["timestamp"];
    String fechaHora = "";

    if (ts != null) {
      final date = ts.toDate();
      fechaHora = DateFormat('dd/MM/yyyy hh:mm a').format(date);
    }

    return Card(
      margin: EdgeInsets.only(bottom: 10.r),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: ListTile(

        onTap: () {
          _verDatosConductor(context, data);
        },

        title: Text(
          usuario,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14.r,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (apto.isNotEmpty)
              Text("Apto: $apto", style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1
              )),

            Text(
              "Solicitud: $fechaHora",
              style: TextStyle(
                fontSize: 10.r,
                color: Colors.black,
              ),
            ),

            SizedBox(height: 4.r),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 3.r),
              decoration: BoxDecoration(
                color: colorEstado.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                textoEstado,
                style: TextStyle(
                  fontSize: 12.r,
                  fontWeight: FontWeight.w700,
                  color: colorEstado,
                ),
              ),
            ),
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