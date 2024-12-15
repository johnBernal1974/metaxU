import 'package:apptaxis/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'dart:core';

import '../../helpers/conectivity_service.dart';
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
  final ConnectionService connectionService = ConnectionService();
  int _currentPage = 0;
  late MyAuthProvider _authProvider;
  late ClientProvider _clientProvider;
  late ProgressDialog _progressDialog;
  FocusNode _nameFocusNode = FocusNode();
  FocusNode _apellidosFocusNode = FocusNode();
  FocusNode _emailFocusNode = FocusNode();
  FocusNode _emailConfirmFocusNode = FocusNode();
  FocusNode _celularFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _passwordDonfirmFocusNode = FocusNode();


  // Variables para almacenar los datos ingresados por el usuario.
  String? name;
  String? apellidos;
  String? email;
  String? emailConfirm;
  String? celular;
  String? password;
  String? passwordConfirm;
  String? selectedQuestion;
  String? answer;

  // Variables para almacenar los errores
  String? nameError;
  String? apellidosError;
  String? emailError;
  String? emailConfirmError;
  String? celularError;
  String? passwordError;
  String? passwordConfirmError;
  String? answerError;


  // Controladores para los campos de texto
  final TextEditingController nameController = TextEditingController();
  final TextEditingController apellidosController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController emailConfirmController = TextEditingController();
  final TextEditingController celularController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController = TextEditingController();
  final TextEditingController answerController = TextEditingController();

  // Opciones para las preguntas
  final List<String> questions = [
    'Nombre de tu mascota',
    'Nombre de tu abuelo materno',
    '¿Cuál es el nombre de tu profesor favorito?',
  ];


  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _authProvider = MyAuthProvider();

      _clientProvider = ClientProvider();
      _progressDialog = ProgressDialog(context);
     _checkConnection();


    });
  }

  Future<void> _checkConnection() async {
    await connectionService.checkConnectionAndShowCard(context, () {
      setState(() {
      });
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
    answerController.dispose();
    _nameFocusNode.dispose();
    _apellidosFocusNode.dispose();
    _emailFocusNode.dispose();
    _emailConfirmFocusNode.dispose();
    _celularFocusNode.dispose();
    _passwordFocusNode.dispose();
    _passwordDonfirmFocusNode.dispose();
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
      answerError = null;

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

      if (_currentPage == 7 && (answer == null)) {
        answerError = "Debes escribir tu respuesta.";
        return;
      }

      // Avanzar de página si no hay errores
      if (_currentPage < 7) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _currentPage++;
      } else {

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
    // Usamos un post-frame callback para asegurarnos de que el foco se maneje después de la renderización
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPage == 1) {
        FocusScope.of(context).requestFocus(_apellidosFocusNode);
        // Asegúrate de que el teclado se muestre después de que el foco haya sido aplicado
        SystemChannels.textInput.invokeMethod('TextInput.show');
      } else if (_currentPage == 2) {
        FocusScope.of(context).requestFocus(_emailFocusNode);
        SystemChannels.textInput.invokeMethod('TextInput.show');
      } else if (_currentPage == 3) {
        FocusScope.of(context).requestFocus(_emailConfirmFocusNode);
        SystemChannels.textInput.invokeMethod('TextInput.show');
      } else if (_currentPage == 4) {
        FocusScope.of(context).requestFocus(_celularFocusNode);
        SystemChannels.textInput.invokeMethod('TextInput.show');
      } else if (_currentPage == 5) {
        FocusScope.of(context).requestFocus(_passwordFocusNode);
        SystemChannels.textInput.invokeMethod('TextInput.show');
      } else if (_currentPage == 6) {
        FocusScope.of(context).requestFocus(_passwordDonfirmFocusNode);
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });

    return Scaffold(
      backgroundColor: blancoCards,
      key: key,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text("Registro", style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20
        )),
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
            value: (_currentPage + 1) / 8, // Cambiar 3 por 7
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
                _buildPalabraClave()
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
                        Icon(Icons.keyboard_double_arrow_left, color: Colors.black, size: 16),
                        Text(
                          "Atrás",
                          style: TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    if (_currentPage == 7) {
                      // Verificar conexión a Internet antes de ejecutar la acción
                      bool hasConnection = await connectionService.hasInternetConnection();

                      if (hasConnection) {
                        // Si hay conexión, ejecuta la acción de ir a "Olvidaste tu contraseña"
                        _register();
                      } else {
                        // Si no hay conexión, muestra un AlertDialog
                        alertSinInternet();
                      }
                    } else {
                      _nextPage();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _currentPage == 7 ? "Registrar" : "Siguiente",
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const Icon(Icons.double_arrow_rounded, color: Colors.black, size: 16),
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

  Future alertSinInternet (){
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sin Internet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),),
          content: const Text('Por favor, verifica tu conexión e inténtalo nuevamente.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  void _register() async {
    _progressDialog.show();
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
            fotoPerfilTomada: false,
            palabraClave: answer ?? "",
            preguntaPalabraClave: selectedQuestion ?? ""
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
            focusNode: _apellidosFocusNode,
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
            focusNode: _emailFocusNode,
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
            focusNode: _emailConfirmFocusNode,
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
            focusNode: _celularFocusNode,
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
            focusNode: _passwordFocusNode,
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
        mainAxisAlignment: MainAxisAlignment.start,
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
            focusNode: _passwordDonfirmFocusNode,
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

  Widget _buildPalabraClave() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            "Verificación de identidad",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Selecciona una pregunta de seguridad y proporciona tu respuesta",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black38),
          ),
          const SizedBox(height: 16),
          // Dropdown para seleccionar la pregunta
          DropdownButton<String>(
            hint: const Text("Selecciona una pregunta"),
            value: selectedQuestion,
            onChanged: (String? newValue) {
              setState(() {
                selectedQuestion = newValue;
              });
            },
            items: questions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 14), // Puedes personalizar el tamaño aquí
                  maxLines: 2,  // Esto asegura que el texto se ajuste en 2 líneas
                  overflow: TextOverflow.ellipsis, // En caso de que sea más largo que 2 líneas
                ),
              );
            }).toList(),
          ),
          // Mostrar un error si no se seleccionó una pregunta
          const SizedBox(height: 16),
          // TextField para ingresar la respuesta
          TextField(
            controller: answerController,
            onChanged: (value) {
              answer = value;
            },
            decoration: InputDecoration(
              labelText: "Escribe tu respuesta",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),

        ],git
      ),
    );
  }

}
