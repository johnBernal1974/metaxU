import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/client_provider.dart';
import '../../../../providers/storage_provider.dart';
import 'package:apptaxis/models/client.dart';

class TakeFotoController {

  late BuildContext context;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  late StorageProvider _storageProvider = StorageProvider();
  late MyAuthProvider _authProvider;
  late ClientProvider _clientProvider;
  XFile? pickedFile;
  File? imageFile;
  late Function refresh;


  Future? init(BuildContext context, Function refresh) {
    this.context = context;
    this.refresh = refresh;
    _authProvider = MyAuthProvider();
    _clientProvider = ClientProvider();
    _storageProvider = StorageProvider();
    return null;
  }

  void guardarFotoPerfil() async {
    showSimpleProgressDialog(context, 'Cargando imagen...');

    if (pickedFile == null) {
      closeSimpleProgressDialog(context);
      return;
    }

    try {
      final uid = _authProvider.getUser()!.uid;

      // ✅ Comprimir imagen
      File compressedImage = await compressImage(File(pickedFile!.path));

      PickedFile compressedPickedFile = PickedFile(compressedImage.path);

      // ✅ Subir a Storage
      TaskSnapshot snapshot = await _storageProvider.uploadProfilePhoto(
        compressedPickedFile,
        uid,
      );

      final String imageUrl = await snapshot.ref.getDownloadURL();

      // 🔥 OBTENER ESTADO ACTUAL
      final doc = await FirebaseFirestore.instance
          .collection('Clients')
          .doc(uid)
          .get();

      final estadoActual = doc.data()?['foto_perfil_estado'] ?? "";

      String nuevoEstado = "tomada";

      if (estadoActual == "rechazada") {
        nuevoEstado = "corregida";
      }

      // ✅ NUEVO SISTEMA LIMPIO
      final Map<String, dynamic> data = {
        'foto_perfil_url': imageUrl,
        'foto_perfil_estado': nuevoEstado,

        // 🔒 flujo admin
        'status': 'procesando',
      };

      await _clientProvider.update(data, uid);

      if (context.mounted) {
        closeSimpleProgressDialog(context);

        Navigator.pushNamedAndRemoveUntil(
          context,
          'verificacion_pendiente',
              (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        closeSimpleProgressDialog(context);
      }
    }
  }

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

  // Función para comprimir la imagen
  Future<File> compressImage(File imageFile) async {
    try {
      // Comprimir la imagen con una calidad específica (entre 0 y 100)
      List<int> compressedImage = (await FlutterImageCompress.compressWithFile(
        imageFile.path,
        quality: 75, // Calidad de compresión
      )) as List<int>;
      // Guardar la imagen comprimida en un nuevo archivo
      File compressedFile = File('${imageFile.parent.path}/${DateTime
          .now()
          .millisecondsSinceEpoch}.jpg');
      await compressedFile.writeAsBytes(compressedImage);
      return compressedFile;
    } catch (e) {
      if (kDebugMode) {
        print('Error al comprimir la imagen: $e');
      }
      // En caso de error, devuelve la imagen original sin comprimir
      return imageFile;
    }
  }

  void closeSimpleProgressDialog(BuildContext context) {
    Navigator.of(context).pop();
  }


  void verificarRutaPagina() {
    _authProvider.checkIfUserIsLogged(context);
  }

  Future<bool?> isEmailVerified() async {
    try {
      // Obtén el usuario actual
      User? user = FirebaseAuth.instance.currentUser;

      // Verifica si el usuario está autenticado
      if (user != null) {
        // Actualiza la información del usuario
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        // Retorna el estado de verificación del email
        return user?.emailVerified;
      } else {
        // Si no hay usuario autenticado, retorna falso
        return false;
      }
    } catch (e) {
      print('Error al verificar si el email está verificado: $e');
      return false;
    }
  }

  void goToMapClient(){
    Navigator.pushNamedAndRemoveUntil(context, "map_client", (route) => false);
  }


  void takePicture() async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image != null) {
      pickedFile = image;
      refresh();
    } else {
      if (kDebugMode) {
        print('No se tomó ninguna foto');
      }
    }
  }
}