

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/client_provider.dart';
import 'package:apptaxis/models/client.dart';

import '../../helpers/session_manager.dart';
import '../../helpers/snackbar.dart';

class LoginController{

  late BuildContext  context;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  late MyAuthProvider _authProvider;
  late ClientProvider _clientProvider;

  Future? init (BuildContext context) {
    this.context = context;
    _authProvider = MyAuthProvider();
    _clientProvider = ClientProvider();
    return null;
  }

  void showSimpleAlertDialog(BuildContext context, String message) {
    showDialog(
      context: context,
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

  void goToRegisterPage(){
    Navigator.pushNamed(context, 'signup');
  }

  void goToForgotPassword(){
    Navigator.pushNamed(context, 'forgot_password');
  }


  Future<void> login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Snackbar.showSnackbar(context, 'Debes ingresar tus credenciales');
      return;
    }
    if (password.length < 6) {
      Snackbar.showSnackbar(context, 'La contraseña debe tener mínimo 6 caracteres');
      return;
    }

    try {
      final ok = await _authProvider.login(email, password, context);
      if (!ok) return;

      final uid = _authProvider.getUser()!.uid;
      Client? client = await _clientProvider.getById(uid);

      if (client == null) {
        if (!context.mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Acceso denegado'),
            content: const Text(
              'Este usuario no pertenece a la aplicación. '
                  'Si crees que es un error, contacta al soporte.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );

        await _authProvider.signOut();
        return;
      }
      try {
        await SessionManager.loginGuard(collection: 'Clients');
      } catch (e) {
        if(context.mounted){
          Snackbar.showSnackbar(
            context,
            'Este usuario ya está logueado en otro dispositivo. '
                'Por favor, cierre sesión allá o espere unos minutos.',
          );
        }
        await _authProvider.signOut();
        return;
      }

      SessionManager.startHeartbeat(collection: 'Clients');

      if (context.mounted) {
        _authProvider.checkIfUserIsLogged(context);
      }
    } catch (error) {
      if (context.mounted) {
        Snackbar.showSnackbar(context, 'Error: $error');
      }
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      final cred = await _authProvider.signInWithGoogle();
      if (cred == null) return; // canceló

      // ✅ si todo bien, tu guard decide si manda a foto/mapa/etc
      if (context.mounted) {
        _authProvider.checkIfUserIsLogged(context);
      }
    } catch (e) {
      if (context.mounted) {
        Snackbar.showSnackbar(context, 'Error al iniciar con Google.');
      }
    }
  }


}

