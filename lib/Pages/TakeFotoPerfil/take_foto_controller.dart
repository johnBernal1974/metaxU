import 'dart:io';
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

      // ✅ Comprimir la imagen antes de subirla
      File compressedImage = await compressImage(File(pickedFile!.path));

      // ✅ Convertir a PickedFile (tu StorageProvider lo pide así)
      PickedFile compressedPickedFile = PickedFile(compressedImage.path);

      // ✅ Subir a Storage
      TaskSnapshot snapshot = await _storageProvider.uploadProfilePhoto(
        compressedPickedFile,
        uid,
      );

      final String imageUrl = await snapshot.ref.getDownloadURL();

      // ✅ IMPORTANTÍSIMO: guardar TODO en 1 SOLO UPDATE
      // Alineado con el guard: the15FotoPerfilUsuario + fotoPerfilTomada
      final Map<String, dynamic> data = {
        // si tu app usa "image" en otros lados, lo mantenemos
        'image': imageUrl,

        // el campo que tu guard revisa como the15FotoPerfilUsuario
        // (en tu updateFotoPerfilATrue usabas este nombre)
        '15_Foto_perfil_usuario': imageUrl,

        // flag que revisa el guard (client.fotoPerfilTomada)
        'foto_perfil_tomada': true,

        // status opcional
        'status': 'foto_tomada',
      };

      await _clientProvider.update(data, uid);

      if (context.mounted) {
        closeSimpleProgressDialog(context);

        // ✅ deja que tu guard decida a dónde ir (mapa / preguntas / etc.)
        _authProvider.checkIfUserIsLogged(context);
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

  void updateFotoPerfilATrue() async {
    String userId = _authProvider.getUser()!.uid;
    Client? client = await _clientProvider.getById(userId);
    if (client != null) {
      bool isFotoTomada = client.fotoPerfilTomada;
      Map<String, dynamic> data;
      if (!isFotoTomada) {
        // Si la foto no está tomada, actualiza el estado y marca la foto como tomada
        data = {
          'status': "foto_tomada",
          '15_Foto_perfil_usuario': "tomada",
          'foto_perfil_tomada': true,
        };
      } else {
        // Si la foto ya está tomada, actualiza solo el estado a "corregida"
        data = {
          'status': "corregida",
          '15_Foto_perfil_usuario': "corregida"
        };
      }
      await _clientProvider.update(data, userId);
    }
  }
}