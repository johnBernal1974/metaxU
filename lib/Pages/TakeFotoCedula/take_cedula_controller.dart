import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class TakeCedulaController {
  late BuildContext context;
  late Function refresh;

  XFile? pickedFront;
  XFile? pickedBack;

  bool get hasFront => pickedFront != null;
  bool get hasBack => pickedBack != null;


  Future? init(BuildContext context, Function refresh) {
    this.context = context;
    this.refresh = refresh;
    return null;
  }

  Future<void> takeFront() async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image != null) {
      pickedFront = image;
      refresh();
    } else {
      if (kDebugMode) print('No se tomó foto frontal');
    }
  }

  Future<void> takeBack() async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image != null) {
      pickedBack = image;
      refresh();
    } else {
      if (kDebugMode) print('No se tomó foto reverso');
    }
  }

  bool get hasBoth => pickedFront != null && pickedBack != null;

  File? get frontFile => pickedFront == null ? null : File(pickedFront!.path);
  File? get backFile => pickedBack == null ? null : File(pickedBack!.path);

  // -------- UI helpers (igual a tu TakeFotoController) --------

  void showSimpleProgressDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  void closeSimpleProgressDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  // -------- compresión (igual al tuyo) --------
  Future<File> compressImage(File imageFile) async {
    try {
      final bytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        quality: 75,
      );

      if (bytes == null) return imageFile;

      final compressedFile = File(
        '${imageFile.parent.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await compressedFile.writeAsBytes(bytes);
      return compressedFile;
    } catch (e) {
      if (kDebugMode) print('Error al comprimir imagen: $e');
      return imageFile;
    }
  }

  // ✅ SUBIR CÉDULA COMPLETA
  Future<void> guardarCedula({required String tipo}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ Validación según tipo (para que no se salga silencioso)
    if (tipo == 'frontal' && pickedFront == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero toma la foto FRONTAL.')),
        );
      }
      return;
    }

    if (tipo == 'reverso' && pickedBack == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero toma la foto REVERSO.')),
        );
      }
      return;
    }

    if (tipo == 'ambas' && (pickedFront == null || pickedBack == null)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero toma la foto FRONTAL y REVERSO.')),
        );
      }
      return;
    }

    showSimpleProgressDialog(context, 'Subiendo cédula...');

    try {
      final uid = user.uid;
      final updates = <String, dynamic>{};

      // ---------- FRONTAL ----------
      if (tipo == 'frontal' || tipo == 'ambas') {
        final frontCompressed = await compressImage(File(pickedFront!.path));

        final frontRef = FirebaseStorage.instance
            .ref()
            .child('images/clientes/$uid/cedula_frontal.jpg');

        final frontSnap = await frontRef.putFile(
          frontCompressed,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        final frontUrl = await frontSnap.ref.getDownloadURL();

        updates.addAll({
          'cedula_frontal_tomada': true,
          '16_Cedula_frontal_usuario': 'corregida', // pendiente implícito
          '16_Cedula_frontal_url': frontUrl,
        });
      }

      // ---------- REVERSO ----------
      if (tipo == 'reverso' || tipo == 'ambas') {
        final backCompressed = await compressImage(File(pickedBack!.path));

        final backRef = FirebaseStorage.instance
            .ref()
            .child('images/clientes/$uid/cedula_reverso.jpg');

        final backSnap = await backRef.putFile(
          backCompressed,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        final backUrl = await backSnap.ref.getDownloadURL();

        updates.addAll({
          'cedula_reverso_tomada': true,
          '23_Cedula_reverso_usuario': 'corregida',
          '23_Cedula_reverso_url': backUrl,
        });
      }

      // ✅ Guardar en Firestore
      await FirebaseFirestore.instance
          .collection('Clients')
          .doc(uid)
          .set(updates, SetOptions(merge: true));

      if (context.mounted) {
        closeSimpleProgressDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento enviado. ¡Gracias!')),
        );
        Navigator.pop(context); // vuelve a la pantalla anterior
      }
    } catch (e) {
      if (kDebugMode) print('Error subiendo cédula: $e');

      if (context.mounted) {
        closeSimpleProgressDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo subir. Intenta nuevamente.')),
        );
      }
    }
  }

}
