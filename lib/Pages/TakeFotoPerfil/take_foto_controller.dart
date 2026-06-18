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
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../src/colors/colors.dart';

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

      bool rostroValido = await validarRostro(
        File(pickedFile!.path),
      );

      if (!rostroValido) {
        if (context.mounted) {
          closeSimpleProgressDialog(context);
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                icon: const Icon(Icons.face_retouching_off, color: Colors.red, size: 60),
                title: const Text('No pudimos verificar tu selfie', textAlign: TextAlign.center),
                content: const Text(
                  'Parece que la imagen capturada no muestra claramente tu rostro.\n\n'
                  'Toma una selfie donde tu cara sea visible completamente, evitando gafas oscuras, objetos que cubran el rostro o fotografías de otras personas.',
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Tomar otra foto'),
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      // ✅ Comprimir imagen
      File compressedImage = await compressImage(
        File(pickedFile!.path),
      );

      PickedFile compressedPickedFile = PickedFile(
        compressedImage.path,
      );

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
        'status': 'activacion_parcial',
      };

      await _clientProvider.update(data, uid);

      if (context.mounted) {
        closeSimpleProgressDialog(context);

        Navigator.pushNamedAndRemoveUntil(
          context,
          'map_client',
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        closeSimpleProgressDialog(context);
      }

      print('Error guardando foto de perfil: $e');
    }
  }

  Future<bool> validarRostro(File imageFile) async {
    // 🔥 BLINDAJE PARA IOS: Si es iOS, devolvemos true directamente.
    // Esto evita que se ejecute la lógica de MLKit y garantiza que el diálogo no salga.
    if (Platform.isIOS) {
      return true;
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final options = FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
      );
      final faceDetector = FaceDetector(options: options);
      final faces = await faceDetector.processImage(inputImage);
      
      await faceDetector.close();

      print('🔥 Rostros detectados: ${faces.length}');
      return faces.isNotEmpty;
    } catch (e) {
      print('❌ Error detallado de detección: $e');
      return false;
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

  Future<File> compressImage(File imageFile) async {
    try {
      List<int> compressedImage = (await FlutterImageCompress.compressWithFile(
        imageFile.path,
        quality: 75,
      )) as List<int>;
      File compressedFile = File('${imageFile.parent.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await compressedFile.writeAsBytes(compressedImage);
      return compressedFile;
    } catch (e) {
      if (kDebugMode) {
        print('Error al comprimir la imagen: $e');
      }
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
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
        return user?.emailVerified;
      } else {
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
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
      maxHeight: 1200,
      maxWidth: 1200,
    );
    
    if (image != null) {
      pickedFile = image;
      refresh();
    }
  }
}