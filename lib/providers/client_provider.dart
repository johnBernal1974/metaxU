

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:apptaxis/models/client.dart';

class ClientProvider{

  late CollectionReference _ref;

  ClientProvider (){
    _ref = FirebaseFirestore.instance.collection('Clients');
  }

  Future<void> create(Client client) async {
    try {
      final doc = await _ref.doc(client.id).get();

      if (doc.exists) {
        throw Exception('El usuario ya existe');
      }

      await _ref.doc(client.id).set(client.toJson());
    } catch (e) {
      rethrow;
    }
  }

  Stream<DocumentSnapshot> getByIdStream(String id) {
    return _ref.doc(id).snapshots(includeMetadataChanges: true);
  }

  Future<Client?> getById(String id) async {
    DocumentSnapshot document = await _ref.doc(id).get();
    if(document.exists){
      Client? client= Client.fromJson(document.data() as Map<String, dynamic>);
      return client;
    }
    else{
      return null;
    }

  }

  Future<void> update(Map<String, dynamic> data, String id) {
    return _ref.doc(id).update(data);
  }

  Future<String?> getStatus() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot snapshot = await _ref.doc(user.uid).get();
        if (snapshot.exists) {
          Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;
          return userData['status'];
        }
      }
      return null;
    } catch (error) {
      if (kDebugMode) {
        print('Error al obtener el estado de verificación: $error');
      }
      return null;
    }
  }

  // Future<String> verificarFotoPerfil() async {
  //   try {
  //     // Obtener la referencia del usuario actual
  //     User? user = FirebaseAuth.instance.currentUser;
  //     if (user != null) {
  //       // Obtener el estado de la foto de perfil del usuario actual desde la base de datos
  //       DocumentSnapshot snapshot = await FirebaseFirestore.instance.collection('Clients').doc(user.uid).get();
  //       if (snapshot.exists) {
  //         // Verificar si la foto de perfil está verificada o no
  //         Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;
  //         String fotoPerfil = userData['15_Foto_perfil_usuario'];
  //         return fotoPerfil;
  //       } else {
  //         // Si no se encuentra el documento del usuario, la foto de perfil no está verificada
  //         return "false";
  //       }
  //     } else {
  //       // Si no hay usuario autenticado, retornar false
  //       return "false";
  //     }
  //   } catch (error) {
  //     if (kDebugMode) {
  //       print('Error al verificar la foto de perfil: $error');
  //     }
  //     return "false";
  //   }
  // } para validacion de foto de perfil

  Future<String> verificarFotoPerfil() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'sin_sesion';

      final snap = await FirebaseFirestore.instance
          .collection('Clients')
          .doc(user.uid)
          .get();

      if (!snap.exists) return 'sin_perfil';

      final data = snap.data() as Map<String, dynamic>?;

      if (data == null) return 'sin_datos';

      final raw = data['15_Foto_perfil_usuario'];
      final estado = (raw ?? '').toString().trim().toLowerCase();

      // Solo 3 opciones reales:
      // "" | "aceptada" | "rechazada"
      if (estado.isEmpty) return 'sin_foto';
      if (estado == 'aceptada') return 'aceptada';
      if (estado == 'rechazada') return 'rechazada';

      // Si por algún motivo llega algo raro, lo tratamos como sin foto
      return 'sin_foto';
    } catch (e) {
      if (kDebugMode) print('Error verificarFotoPerfil: $e');
      return 'error';
    }
  }

  //Nuevos métodos para gestionar el estado de inicio de sesión
  Future<bool> checkIfUserIsLoggedIn(String userId) async {
    DocumentSnapshot snapshot = await _ref.doc(userId).get();
    if (snapshot.exists) {
      Map<String, dynamic>? userData = snapshot.data() as Map<String, dynamic>?; // Cambiado
      return userData?['isLoggedIn'] ?? false; // Cambiado
    }
    return false; // Usuario no encontrado
  }

  Future<void> updateLoginStatus(String userId, bool isLoggedIn) async {
    await _ref.doc(userId).update({'isLoggedIn': isLoggedIn});
  }

  Future<bool> existsByCelular(String celular) async {
    final query = await _ref
        .where('the07Celular', isEqualTo: celular)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  //para validar si se pide la cedula

  Future<Map<String, dynamic>> getConfigCedula() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Prices')
          .doc('info')
          .get();

      if (!snap.exists) {
        return {
          'cedula': false,
          'cedula_despues_de_viajes': 1,
        };
      }

      final data = snap.data() as Map<String, dynamic>?;

      final bool pedir = (data?['cedula'] == true);
      final int despues = (data?['cedula_despues_de_viajes'] is num)
          ? (data!['cedula_despues_de_viajes'] as num).toInt()
          : 1;

      return {
        'cedula': pedir,
        'cedula_despues_de_viajes': despues,
      };
    } catch (_) {
      return {
        'cedula': false,
        'cedula_despues_de_viajes': 1,
      };
    }
  }


}