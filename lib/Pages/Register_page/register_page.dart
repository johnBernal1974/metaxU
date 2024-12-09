import 'package:apptaxis/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'dart:core';

import '../../helpers/snackbar.dart';
import '../../providers/client_provider.dart';
import '../../src/colors/colors.dart';
import 'package:apptaxis/models/client.dart';

import '../TakeFotoPerfil/take_foto_perfil_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late MyAuthProvider _authProvider;
  late ClientProvider _clientProvider;
  late ProgressDialog _progressDialog;

  // Variables para almacenar los datos ingresados por el usuario.
  String? name;
  String? apellidos;
  String? email;
  String? emailConfirm;
  String? celular;
  String? password;
  String? passwordConfirm;

  // Variables para almacenar los errores
  String? nameError;
  String? apellidosError;
  String? emailError;
  String? emailConfirmError;
  String? celularError;
  String? passwordError;
  String? passwordConfirmError;

  // Controladores para los campos de texto
  final TextEditingController nameController = TextEditingController();
  final TextEditingController apellidosController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController emailConfirmController = TextEditingController();
  final TextEditingController celularController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _authProvider = MyAuthProvider();

      _clientProvider = ClientProvider();
      _progressDialog = ProgressDialog(context);
      // _checkConnection();
      // checkForUpdate();
      // _loadSearchHistory();

    });
  }

  @override
  void dispose() {
    // Liberar los controladores cuando no se necesiten
    nameController.dispose();
    apellidosController.dispose();
    emailController.dispose();
    emailConfirmController.dispose();
    celularController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }

  // Método para avanzar a la siguiente página
  void _nextPage() {
    setState(() {
      // Limpiar errores antes de cada validación
      nameError = null;
      apellidosError = null;
      emailError = null;
      emailConfirmError = null;
      celularError = null;
      passwordError = null;
      passwordConfirmError = null;

      // Validaciones
      if (_currentPage == 0 && (name == null || name!.isEmpty)) {
        nameError = "Por favor ingresa tu nombre.";
        return;
      }
      if (_currentPage == 1 && (apellidos == null || apellidos!.isEmpty)) {
        apellidosError = "Por favor ingresa tus apellidos.";
        return;
      }
      if (_currentPage == 2 && (email == null || email!.isEmpty)) {
        emailError = "Por favor ingresa un correo electrónico.";
        return;
      }

      if (_currentPage == 2 && !_isValidEmail(email!)) {
        emailError = "Este correo electrónico NO es válido.";
        return;
      }

      if (_currentPage == 3 && (emailConfirm == null)) {
        emailConfirmError = "Por favor ingresa un correo electrónico.";
        return;
      }

      if (_currentPage == 3 &&  !_isValidEmail(emailConfirm!)) {
        emailConfirmError = "Este correo electrónico NO es válido.";
        return;
      }

      if (_currentPage == 3 && (emailConfirm != email)) {
        emailConfirmError = "El correo de confirmación no coincide.";
        return;
      }

      if (_currentPage == 4 && (celular == null || celular!.isEmpty)) {
        celularError = "Por favor ingresa tu número de celular.";
        return;
      }
      if (_currentPage == 4 && celular!.length != 10) {
        celularError = "Este número de celular NO es válido.";
        return;
      }
      if (_currentPage == 5 && (password == null || password!.isEmpty)) {
        passwordError = "Por favor ingresa una contraseña.";
        return;
      }
      if (_currentPage == 5 && password!.length < 6) {
        passwordError = "Por favor ingresa una contraseña con mínimo 6 caracteres.";
        return;
      }
      if (_currentPage == 6 && (passwordConfirm == null)) {
        passwordConfirmError = "Por favor ingresa una contraseña.";
        return;
      }

      if (_currentPage == 6 && passwordConfirm!.length < 6) {
        passwordConfirmError = "Por favor ingresa una contraseña con mínimo 6 caracteres.";
        return;
      }

      if (_currentPage == 6 && (passwordConfirm != password)) {
        passwordConfirmError = "Las contraseñas no coinciden.";
        return;
      }

      // Avanzar de página si no hay errores
      if (_currentPage < 6) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _currentPage++;
      } else {
        // Registro final
        _register();
      }
    });
  }


  // Método para retroceder a la página anterior
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage--;
      });
    }
  }


  // Método para validar el formato del correo electrónico
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$");
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blancoCards,
      key: key,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text("Registro", style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20
        ),),
        actions: const <Widget>[
          Image(
              height: 40.0,
              width: 100.0,
              image: AssetImage('assets/metax_logo.png'))
        ],
      ),
      body: Column(
        children: [
          // Indicador de progreso
          LinearProgressIndicator(
            value: (_currentPage + 1) / 7, // Cambiar 3 por 7
            backgroundColor: Colors.grey[300],
            color: primary,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildNamePage(),
                _buildApellidosPage(),
                _buildEmailPage(),
                _buildEmailConfirmPage(),
                _buildCelularPage(),
                _buildPasswordPage(),
                _buildPasswordConfirmPage(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  ElevatedButton(
                    onPressed: _previousPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.keyboard_double_arrow_left, color: Colors.black, size: 16,),
                        Text(
                          "Atrás",
                          style: TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _currentPage == 6 ? "Registrar" : "Siguiente", // Cambiar 2 por 6
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const Icon(Icons.double_arrow_rounded, color: Colors.black, size: 16,),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _register() async {
    // Aquí validarías el formulario, guardarías la información, etc.
    try{
      bool isSignUp =  await _authProvider.signUp(email!, password!);
      if(isSignUp){
        Client client = Client(
            id: _authProvider.getUser()!.uid,
            the01Nombres: name ?? "",
            the02Apellidos: apellidos ?? "",
            the06Email: email ?? "",
            the07Celular: celular ?? "",
            the09Genero: "",
            the15FotoPerfilUsuario: "",
            the17Bono: 0,
            the18Calificacion: 0,
            the19Viajes: 0,
            the20Rol: "basico",
            the21FechaDeRegistro: Timestamp.now(),
            token: "",
            image: "",
            status: "registrado",
            the00isTraveling: false,
            the22Cancelaciones: 0,
            the41SuspendidoPorCancelaciones: false,
            fotoPerfilTomada: false
        );

        await _clientProvider.create(client);
        _progressDialog.hide();
        _goTakeFotoPerfil();
      }
      else{
        _progressDialog.hide();
      }
    }catch (error) {
      _progressDialog.hide();
      if (kDebugMode) {
        print('Error durante el registro: $error');
      }

      if (error is FirebaseAuthException) {
        if (error.code == 'email-already-in-use') {
          Snackbar.showSnackbar(key.currentContext!, key,
              'El correo electrónico ya está en uso por otra cuenta.');
        } else {
          Snackbar.showSnackbar(key.currentContext!, key,
              'Ocurrió un error durante el registro. Por favor, inténtalo nuevamente.');
        }
      } else {
        Snackbar.showSnackbar(key.currentContext!, key,
            'Ocurrió un error durante el registro. Por favor, inténtalo nuevamente.');
      }
    }

  }

  void _goTakeFotoPerfil(){
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const TakeFotoPerfil()),
    );
  }

  // Página para ingresar el nombre
  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,

        children: [
          const Text(
            "¡Vamos a crear tu cuenta!",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black, height: 0.8),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),
          const Text(
            "¿Cuáles son tus nombres?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Solo nombres sin los apeliidos",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            onChanged: (value) {
              setState(() {
                name = value; // Actualiza el valor de name al escribir
              });
            },
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: "Nombres",
              errorText: nameError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Página para ingresar los apellidos
  Widget _buildApellidosPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            "¿Cuáles son tus apellidos?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: apellidosController,
            onChanged: (value) => apellidos = value,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: "Apellidos",
              errorText: apellidosError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Página para ingresar el correo electrónico
  Widget _buildEmailPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            "¿Cuál es tu correo electrónico?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Debe ser una cuenta activa, de lo contrario no podrás ingresar más adelante",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black38),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailController,
            onChanged: (value) => email = value,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: "Correo electrónico",
              errorText: emailError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Página para confirmar el correo electrónico
  Widget _buildEmailConfirmPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            "¿Confirma tu correo electrónico?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailConfirmController,
            onChanged: (value) => emailConfirm = value,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: "Confirmar Correo electrónico",
              errorText: emailConfirmError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Página para ingresar el celular
  Widget _buildCelularPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            "¿Cuál es tu número de celular?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: celularController,
            onChanged: (value) => celular = value,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: "Celular",
              errorText: celularError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Página para ingresar la contraseña
  Widget _buildPasswordPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            "Crea una contraseña",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Debe ser de mínimo 6 caracteres",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black38),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            onChanged: (value) => password = value,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Contraseña",
              errorMaxLines: 2,
              errorText: passwordError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Página para confirmar la contraseña
  Widget _buildPasswordConfirmPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Confirma tu contraseña",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Debe ser de mínimo 6 caracteres",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black38),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordConfirmController,
            onChanged: (value) => passwordConfirm = value,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Confirmar Contraseña",
              errorText: passwordConfirmError,
              errorMaxLines: 2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
