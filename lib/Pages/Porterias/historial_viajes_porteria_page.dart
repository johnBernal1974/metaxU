import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../src/colors/colors.dart';

class HistorialViajesPorteriaPage extends StatelessWidget {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {

    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Usuario no válido")));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary.withOpacity(0.7),
        title: const Text(
          "Historial de viajes",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("TravelRequests")
            .where("porteriaId", isEqualTo: uid)
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.where((doc) {

            final data = doc.data() as Map<String, dynamic>;
            final status = data["status"];

            return status == "cancelledByPorteria" ||
                status == "cancelByDriverAfterAccepted" ||
                status == "cancelTimeIsOver" ||
                status == "finished";

          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text("No hay viajes en el historial"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final data = docs[index].data() as Map<String, dynamic>;

              final usuario = data["usuario"] ?? "";
              final apto = data["apto"] ?? "";
              final status = data["status"] ?? "";

              final Timestamp? ts = data["timestamp"];

              String fecha = "";

              if (ts != null) {
                final date = ts.toDate();
                fecha =
                "${date.day}/${date.month}/${date.year}  ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
              }

              /// ESTADO EN ESPAÑOL
              String estadoTexto;

              switch (status) {
                case "cancelledByPorteria":
                  estadoTexto = "Cancelado por portería";
                  break;

                case "cancelByDriverAfterAccepted":
                  estadoTexto = "Cancelado por conductor";
                  break;

                case "cancelTimeIsOver":
                  estadoTexto = "El usuario no se presentó";
                  break;

                case "finished":
                  estadoTexto = "Viaje finalizado";
                  break;

                default:
                  estadoTexto = status;
              }

              /// COLOR DEL MARCADOR
              Color indicadorColor;

              switch (status) {
                case "cancelledByPorteria":
                  indicadorColor = Colors.red;
                  break;

                case "cancelByDriverAfterAccepted":
                  indicadorColor = Colors.orange;
                  break;

                case "cancelTimeIsOver":
                  indicadorColor = Colors.deepOrange;
                  break;

                case "finished":
                  indicadorColor = Colors.green;
                  break;

                default:
                  indicadorColor = Colors.grey;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// USUARIO Y APTO
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            usuario,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "Apto: $apto",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      /// FECHA
                      Text(
                        fecha,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black45,
                        ),
                      ),

                      const SizedBox(height: 10),

                      /// ESTADO CON MARCADOR
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            /// CIRCULO INDICADOR
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: indicadorColor,
                                shape: BoxShape.circle,
                              ),
                            ),

                            const SizedBox(width: 6),

                            /// TEXTO ESTADO
                            Text(
                              estadoTexto,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),

                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

}