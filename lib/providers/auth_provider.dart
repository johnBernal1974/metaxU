
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apptaxis/models/client.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';

import 'client_provider.dart';

class MyAuthProvider{
  late FirebaseAuth _firebaseAuth;
  StreamSubscription<User?>? _authSub;
  bool _navigating = false;


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
    if (context == null) return;

    // ✅ evita múltiples listeners
    _authSub?.cancel();
    _navigating = false;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (!context.mounted) return;
      if (_navigating) return;

      // 1) No logueado -> login
      if (user == null) {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
        return;
      }

      // 2) Email verificado solo si NO es Google
      final providerIds = user.providerData.map((e) => e.providerId).toList();
      final isGoogle = providerIds.contains('google.com');

      if (!isGoogle && !user.emailVerified) {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'email_verification', (route) => false);
        return;
      }

      final clientProvider = ClientProvider();
      final userId = user.uid;

      // 3) Traer el Client UNA SOLA VEZ (fuente de la verdad)
      final Client? client = await clientProvider.getById(userId);

      if (!context.mounted) return;
      if (_navigating) return;

      if (client == null) {
        // si no hay documento cliente, manda a login
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
        return;
      }

      // 4) Status bloqueado (usa el dato del cliente si lo tienes en el modelo)
      // Si tu status viene en client.status, usa eso.
      final status = (client.status ?? '').trim();
      if (status == 'bloqueado') {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'bloqueo_page', (route) => false);
        return;
      }

      // 5) ✅ Foto obligatoria (robusta)
      final foto = (client.the15FotoPerfilUsuario ?? '').trim();
      final fotoTomada = client.fotoPerfilTomada ?? false;

      if (!fotoTomada || foto.isEmpty || foto == 'rechazada') {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'take_foto_perfil', (route) => false);
        return;
      }

      // 6) ✅ Pregunta y respuesta obligatorias
      final pregunta = (client.preguntaPalabraClave ?? '').trim();
      final respuesta = (client.palabraClave ?? '').trim();

      if (pregunta.isEmpty || respuesta.isEmpty) {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'complete_security', (route) => false);
        return;
      }

      // 7) ✅ Viaje o mapa normal
      final isTraveling = client.the00isTraveling;

      _navigating = true;
      if (isTraveling) {
        Navigator.pushNamedAndRemoveUntil(context, 'travel_map_page', (route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, 'map_client', (route) => false);
      }
    });
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

  void dispose() {
    _authSub?.cancel();
  }


}