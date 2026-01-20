

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

  // void login() async {
  //   String email = emailController.text.trim();
  //   String password = passwordController.text.trim();
  //
  //   if (email.isEmpty || password.isEmpty) {
  //     Snackbar.showSnackbar(context, 'Debes ingresar tus credenciales');
  //     return;
  //   }
  //   if (password.length < 6) {
  //     Snackbar.showSnackbar(context, 'La contraseña debe tener mínimo 6 caracteres');
  //     return;
  //   }
  //
  //   showSimpleAlertDialog(context, 'Espera un momento ...');
  //
  //   try {
  //     bool isLoginSuccessful = await _authProvider.login(email, password, context);
  //
  //     if (isLoginSuccessful) {
  //       Client? client = await _clientProvider.getById(_authProvider.getUser()!.uid);
  //
  //       if (client != null) {
  //         bool isLoggedIn = await _clientProvider.checkIfUserIsLoggedIn(client.id);
  //
  //         if (isLoggedIn) {
  //           if (context.mounted) {
  //             Snackbar.showSnackbar(
  //                 context,
  //                 'Este usuario ya está logueado en otro dispositivo. Por favor, cierre sesión en el otro equipo para continuar.'
  //             );
  //           }
  //           await _authProvider.signOut();
  //           return;
  //         }
  //
  //         // Actualizar estado como conectado
  //         await _clientProvider.updateLoginStatus(client.id, true);
  //
  //         if (context.mounted) {
  //           _authProvider.checkIfUserIsLogged(context);
  //         }
  //       } else {
  //         // Manejo de cliente no válido
  //         if (context.mounted) {
  //           Snackbar.showSnackbar(context, 'Este usuario no es válido');
  //         }
  //         await _authProvider.signOut();
  //       }
  //     }
  //   } catch (error) {
  //     if (context.mounted) {
  //       Snackbar.showSnackbar(context, 'Error: $error');
  //     }
  //   } finally {
  //     if (context.mounted) {
  //       closeSimpleProgressDialog(context);
  //     }
  //   }
  // } comentado prueba

  void login() async {
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

    showSimpleAlertDialog(context, 'Espera un momento ...');

    try {
      final ok = await _authProvider.login(email, password, context);
      if (!ok) {
        if (context.mounted) closeSimpleProgressDialog(context);
        return;
      }

      // ✅ 1) Validar + registrar sesión por dispositivo (CLIENTS)
      try {
        await SessionManager.loginGuard(collection: 'Clients');
      } catch (e) {
        // Bloqueado por sesión activa en otro dispositivo
        if (context.mounted) {
          closeSimpleProgressDialog(context);
          Snackbar.showSnackbar(
            context,
            'Este usuario ya está logueado en otro dispositivo. '
                'Por favor, cierre sesión allá o espere unos minutos.',
          );
        }
        await _authProvider.signOut();
        return;
      }

      // ✅ 2) (Opcional) validar que exista el Client en tu colección
      final uid = _authProvider.getUser()!.uid;
      Client? client = await _clientProvider.getById(uid);

      if (client == null) {
        if (context.mounted) {
          closeSimpleProgressDialog(context);
          Snackbar.showSnackbar(context, 'Este usuario no es válido');
        }
        await _authProvider.signOut();
        return;
      }

      // ✅ 3) Navegar como ya lo haces
      if (context.mounted) {
        closeSimpleProgressDialog(context);
        _authProvider.checkIfUserIsLogged(context);
      }
    } catch (error) {
      if (context.mounted) {
        closeSimpleProgressDialog(context);
        Snackbar.showSnackbar(context, 'Error: $error');
      }
    }
  }



}

