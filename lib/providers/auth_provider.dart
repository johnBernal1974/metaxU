
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apptaxis/models/client.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'client_provider.dart';

class MyAuthProvider{
  late FirebaseAuth _firebaseAuth;


  MyAuthProvider(){
    _firebaseAuth = FirebaseAuth.instance;
  }

  BuildContext? get context => null;

  Future<bool> login(String email, String password, BuildContext context) async {
    String? errorMessage;

    try{
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    }on FirebaseAuthException catch (error){
      errorMessage = _getErrorMessage(error.code);
      if(context.mounted){
        showSnackbar(context, errorMessage);
      }
      return false;
    }
    return true;
  }

  String _getErrorMessage(String errorCode) {
    // Mapeo de los códigos de error a mensajes en español
    Map<String, String> errorMessages = {
      'user-not-found': 'Usuario no encontrado. Verifica tu correo electrónico.',
      'wrong-password': 'Contraseña incorrecta. Inténtalo de nuevo.',
      'invalid-email': 'La dirección de correo electrónico no tiene el formato correcto.',
      'user-disabled': 'La cuenta de usuario ha sido deshabilitada.',
      'invalid-credential': 'Las credenciales proporcionadas no son válidas.',
      'network-request-failed': 'Sin señal. Revisa tu conexión de INTERNET.',
      'email-already-in-use': 'El correo electrónico ingresado ya está siendo usado por otro usuario.',
    };

    return errorMessages[errorCode] ?? 'Error desconocido';
  }

  void showSnackbar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontSize: 16),
      ),
      backgroundColor: Colors.black,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  User? getUser(){
    return _firebaseAuth.currentUser;
  }

  //ajutado para que siempre estaen las preguntas de seguridad
  void checkIfUserIsLogged(BuildContext? context) {
    if (context != null) {
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        if (user != null) {
          // Verificar si el correo electrónico está verificado
          final providerIds = user.providerData.map((e) => e.providerId).toList();
          final isGoogle = providerIds.contains('google.com');

          if (!isGoogle && !user.emailVerified) {
            Navigator.pushNamedAndRemoveUntil(context, 'email_verification', (route) => false);
            return;
          }

          ClientProvider clientProvider = ClientProvider();
          String? status = await clientProvider.getStatus();

          if (status == 'bloqueado') {
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                'bloqueo_page',
                    (route) => false,
              );
            }
            return;
          }

          // Verificar foto perfil
          String? fotoPerfilUsuario = await clientProvider.verificarFotoPerfil();

          if (fotoPerfilUsuario == "" || fotoPerfilUsuario == "rechazada") {
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                'take_foto_perfil',
                    (route) => false,
              );
            }
            return;
          }

          // Si todas las fotos están verificadas, verificar si el usuario está viajando
          String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          Client? client = await clientProvider.getById(userId);

          if (client != null) {

            // ✅ NUEVO: Validación obligatoria de pregunta y respuesta
            final pregunta = (client.preguntaPalabraClave ?? '').trim();
            final respuesta = (client.palabraClave ?? '').trim();

            if (pregunta.isEmpty || respuesta.isEmpty) {
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  'complete_security',
                      (route) => false,
                );
              }
              return;
            }

            // ✅ Tu lógica normal
            bool isTraveling = client.the00isTraveling;

            if (isTraveling) {
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  'travel_map_page',
                      (route) => false,
                );
              }
            } else {
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  'map_client',
                      (route) => false,
                );
              }
            }
          } else {
            // Si no se encuentra el cliente, redirigir a login (mejor que map_client)
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                'login',
                    (route) => false,
              );
            }
          }
        } else {
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              'login',
                  (route) => false,
            );
          }
        }
      });
    }
  }

  Future<bool> signUp(String email, String password) async {
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException {
      // Lanzar el error para manejarlo en SignUpController
      rethrow;
    }
    return true;
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
      await _firebaseAuth.signOut();
    } catch (_) {
      await _firebaseAuth.signOut();
    }
  }

  Future<bool> isUserLoggedIn() async {
    // Si usas Firebase Authentication
    var user = FirebaseAuth.instance.currentUser;
    return user != null;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        return await _firebaseAuth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null; // cancelado

        final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _firebaseAuth.signInWithCredential(credential);
      }
    } on FirebaseAuthException {
      rethrow;
    }
  }


}