import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
        title: const Text("Historial de viajes"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("TravelRequests")
            .where("porteriaId", isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.where((doc) {

            final data = doc.data() as Map<String, dynamic>;
            final status = data["status"];

            return status == "completed" || status == "cancelled";

          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text("No hay viajes activos"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final data = docs[index].data() as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  title: Text(data["usuario"] ?? ""),
                  subtitle: Text(data["status"] ?? ""),
                ),
              );

            },
          );
        },
      ),
    );
  }
}