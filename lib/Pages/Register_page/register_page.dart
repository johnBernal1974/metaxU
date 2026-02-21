import 'package:apptaxis/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'dart:core';

import '../../helpers/DateHelpers.dart';
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
  String? questionError;



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

  bool _isGoogleFlow = false;


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

  //para crear con google
  Future<void> _signUpWithGoogleAndContinue() async {
    _progressDialog.show();

    try {
      final cred = await _authProvider.signInWithGoogle();
      if (cred == null) {
        _progressDialog.hide(); // canceló
        return;
      }

      final user = cred.user;
      if (user == null) {
        _progressDialog.hide();
        Snackbar.showSnackbar(key.currentContext!, 'No se pudo obtener tu usuario de Google.');
        return;
      }

      // ✅ Guardamos email (pero NO autollenamos nombres/apellidos)
      email = user.email ?? "";
      emailConfirm = email;

      // ✅ 1) Si ya existe en Firestore -> ir directo al mapa (o donde corresponda)
      final existing = await _clientProvider.getById(user.uid);
      if (existing != null) {
        _progressDialog.hide();

        Snackbar.showSnackbar(key.currentContext!, 'Bienvenido nuevamente 👋');

        if (mounted) {
          _authProvider.checkIfUserIsLogged(context);
        }
        return;
      }

      // ✅ 2) Si NO existe -> es nuevo -> lo llevamos a Nombres (sin autollenar)
      name = null;
      apellidos = null;
      nameController.clear();
      apellidosController.clear();

      setState(() {
        _isGoogleFlow = true;
        _currentPage = 1; // Nombres
      });

      _progressDialog.hide();

      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      _progressDialog.hide();
      if (kDebugMode) {
        print('🔥 ERROR Google Sign-In: $e');
      }
      Snackbar.showSnackbar(key.currentContext!, 'Error al iniciar con Google.');
    }
  }

  // Método para avanzar a la siguiente página
  void _nextPage() {
    setState(() {
      // Limpiar errores antes de validar
      nameError = null;
      apellidosError = null;
      emailError = null;
      emailConfirmError = null;
      celularError = null;
      passwordError = null;
      passwordConfirmError = null;
      answerError = null;
      questionError = null;

      // =========================
      // 1) VALIDAR PÁGINA ACTUAL
      // =========================

      // Pag 1: nombres
      if (_currentPage == 1 && (name == null || name!.trim().isEmpty)) {
        nameError = "Por favor ingresa tu nombre.";
        return;
      }

      // Pag 2: apellidos
      if (_currentPage == 2 && (apellidos == null || apellidos!.trim().isEmpty)) {
        apellidosError = "Por favor ingresa tus apellidos.";
        return;
      }

      // Pag 3: email (solo NO Google)
      if (!_isGoogleFlow && _currentPage == 3) {
        if (email == null || email!.trim().isEmpty) {
          emailError = "Por favor ingresa un correo electrónico.";
          return;
        }
        if (!_isValidEmail(email!.trim())) {
          emailError = "Este correo electrónico NO es válido.";
          return;
        }
      }

      // Pag 4: confirm email (solo NO Google)
      if (!_isGoogleFlow && _currentPage == 4) {
        if (emailConfirm == null || emailConfirm!.trim().isEmpty) {
          emailConfirmError = "Por favor confirma tu correo electrónico.";
          return;
        }
        if (!_isValidEmail(emailConfirm!.trim())) {
          emailConfirmError = "Este correo electrónico NO es válido.";
          return;
        }
        if (emailConfirm!.trim() != (email ?? "").trim()) {
          emailConfirmError = "El correo de confirmación no coincide.";
          return;
        }
      }

      // Pag 5: celular (siempre)
      if (_currentPage == 5) {
        final cel = (celular ?? "").replaceAll(RegExp(r'\D'), '');
        if (cel.isEmpty) {
          celularError = "Por favor ingresa tu número de celular.";
          return;
        }
        if (cel.length != 10) {
          celularError = "Este número de celular NO es válido.";
          return;
        }
      }

      // Pag 6: password (solo NO Google)
      if (!_isGoogleFlow && _currentPage == 6) {
        if (password == null || password!.isEmpty) {
          passwordError = "Por favor ingresa una contraseña.";
          return;
        }
        if (password!.length < 6) {
          passwordError = "Por favor ingresa una contraseña con mínimo 6 caracteres.";
          return;
        }
      }

      // Pag 7: confirm password (solo NO Google)
      if (!_isGoogleFlow && _currentPage == 7) {
        if (passwordConfirm == null || passwordConfirm!.isEmpty) {
          passwordConfirmError = "Por favor confirma tu contraseña.";
          return;
        }
        if (passwordConfirm!.length < 6) {
          passwordConfirmError = "Por favor ingresa una contraseña con mínimo 6 caracteres.";
          return;
        }
        if (passwordConfirm != password) {
          passwordConfirmError = "Las contraseñas no coinciden.";
          return;
        }
      }

      // Pag 8: pregunta/resp (siempre)
      if (_currentPage == 8) {
        if (selectedQuestion == null) {
          questionError = "Debes seleccionar una pregunta.";
          return;
        }
        if (answer == null || answer!.trim().isEmpty) {
          answerError = "Debes escribir tu respuesta.";
          return;
        }
      }

      // =========================
      // 2) NAVEGAR / REGISTRAR
      // =========================

      if (_currentPage == 8) {
        _register();
        return;
      }

      int next = _currentPage + 1;

      // Saltos para Google:
      if (_isGoogleFlow) {
        // Saltar email(3) y confirm(4)
        if (next == 3 || next == 4) next = 5;

        // Saltar password(6) y confirm(7)
        if (next == 6 || next == 7) next = 8;
      }

      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      _currentPage = next;
      _handleFocusForPage(_currentPage);
    });
  }

  // Método para retroceder a la página anterior
  void _previousPage() {
    if (_currentPage <= 0) return;

    int prev = _currentPage - 1;

    if (_isGoogleFlow) {
      // Si es Google, saltar páginas no usadas al retroceder:
      // saltar password(6) y confirm(7)
      if (prev == 7 || prev == 6) prev = 5;
      // saltar email(3) y confirm(4)
      if (prev == 4 || prev == 3) prev = 2;
    }

    _pageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    setState(() => _currentPage = prev);
    _handleFocusForPage(_currentPage);
  }

  // Método para validar el formato del correo electrónico
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$");
    return emailRegex.hasMatch(email);
  }

  void _handleFocusForPage(int page) {
    // Espera un poco a que PageView termine de pintar la página
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;

      FocusNode? node;
      switch (page) {
        case 1:
          node = _nameFocusNode;
          break;
        case 2:
          node = _apellidosFocusNode;
          break;
        case 3:
          node = _emailFocusNode;
          break;
        case 4:
          node = _emailConfirmFocusNode;
          break;
        case 5:
          node = _celularFocusNode;
          break;
        case 6:
          node = _passwordFocusNode;
          break;
        case 7:
          node = _passwordDonfirmFocusNode;
          break;
        default:
          node = null;
      }

      if (node != null) {
        FocusScope.of(context).requestFocus(node);
        SystemChannels.textInput.invokeMethod('TextInput.show'); // ✅ abre teclado
      }
    });
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
            value: (_currentPage + 1) / 9,
            backgroundColor: Colors.grey[300],
            color: primary,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMetodoRegistroPage(), // ✅ nueva pagina 0
                _buildNamePage(),           // ahora es pagina 1
                _buildApellidosPage(),      // 2
                _buildEmailPage(),          // 3
                _buildEmailConfirmPage(),   // 4
                _buildCelularPage(),        // 5
                _buildPasswordPage(),       // 6
                _buildPasswordConfirmPage(),// 7
                _buildPalabraClave(),       // 8
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
                    if (_currentPage == 8) {
                      bool hasConnection = await connectionService.hasInternetConnection();

                      if (hasConnection) {
                        _nextPage();   // ✅ ahora sí valida pregunta/respuesta
                      } else {
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
                        _currentPage == 8 ? "Registrar" : "Siguiente",
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

  Widget _buildMetodoRegistroPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),

          // Logo + headline
          const Center(
            child: Column(
              children: [
                SizedBox(height: 6),
                Text(
                  "Crea tu cuenta en segundos",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.0),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  "Elige cómo quieres continuar",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // ✅ Google (protagonista)
          ElevatedButton(
            onPressed: _signUpWithGoogleAndContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: Colors.black12),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo_google.png',
                  height: 22,
                  width: 22,
                  fit: BoxFit.contain,
                ),
                SizedBox(width: 10),
                const Text(
                  "Continuar con Google",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Divider "o"
          const Row(
            children: [
              Expanded(child: Divider(color: Colors.black12)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text("o", style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)),
              ),
              Expanded(child: Divider(color: Colors.black12)),
            ],
          ),

          const SizedBox(height: 14),

          // ✅ Email (secundario, más pequeño)
          OutlinedButton(
            onPressed: () {
              setState(() {
                _isGoogleFlow = false;
                _currentPage = 1; // ✅ ir a Nombres (nuevo indice)
              });
              _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: const BorderSide(color: Colors.black12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              "Continuar con correo",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),

          const Spacer(),

          // Texto de confianza (queda pro)
          const Text(
            "Tu información está protegida.\nLuego te pediremos tu celular y una verificación rápida.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black45, height: 1.2),
          ),
          const SizedBox(height: 10),
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
    // ✅ SEGURO: valida aquí también (por si alguien llama _register() directo)
    setState(() {
      questionError = null;
      answerError = null;

      if (selectedQuestion == null) {
        questionError = "Debes seleccionar una pregunta.";
      }

      final a = (answer ?? "").trim();
      if (a.isEmpty) {
        answerError = "Debes escribir tu respuesta.";
      }
    });

    // ✅ Si hay errores, NO muestra loading y NO registra
    if (questionError != null || answerError != null) {
      return;
    }

    _progressDialog.show();

    try {
      // ✅ Normaliza celular (solo números)
      final celNormalizado = (celular ?? "").replaceAll(RegExp(r'\D'), '');

      if (celNormalizado.length != 10) {
        _progressDialog.hide();
        Snackbar.showSnackbar(
          key.currentContext!,
          'El número de celular no es válido.',
        );
        return;
      }

      // ✅ 1) Obtener UID (Google o correo/contraseña)
      String uid;

      if (_isGoogleFlow) {
        final user = _authProvider.getUser();
        if (user == null) {
          _progressDialog.hide();
          Snackbar.showSnackbar(
            key.currentContext!,
            'Sesión inválida. Intenta con Google nuevamente.',
          );
          return;
        }
        uid = user.uid;
        email = user.email ?? (email ?? "");
      } else {
        // Flujo normal (correo/contraseña)
        bool isSignUp = await _authProvider.signUp(email!, password!);
        if (!isSignUp) {
          _progressDialog.hide();
          return;
        }
        uid = _authProvider.getUser()!.uid;
      }

      // ✅ 2) Si ya existe en Firestore, NO hacer registro de nuevo
      final existing = await _clientProvider.getById(uid);
      if (existing != null) {
        _progressDialog.hide();

        Snackbar.showSnackbar(
          key.currentContext!,
          'Bienvenido nuevamente 👋',
        );

        if (context.mounted) {
          _authProvider.checkIfUserIsLogged(context);
        }
        return;
      }

      // ✅ 3) Solo para usuarios NUEVOS: validar celular duplicado
      final existeCelular = await _clientProvider.existsByCelular(celNormalizado);
      if (existeCelular) {
        _progressDialog.hide();
        Snackbar.showSnackbar(
          key.currentContext!,
          'Este número de celular ya está registrado. '
              'Intenta iniciar sesión o recuperar tu cuenta.',
        );
        return;
      }

      // ✅ 4) Crear perfil del cliente en Firestore (solo nuevo)
      Client client = Client(
        id: uid,
        the01Nombres: name ?? "",
        the02Apellidos: apellidos ?? "",
        the06Email: email ?? "",
        the07Celular: celNormalizado,
        the09Genero: "",
        the15FotoPerfilUsuario: "",
        the17Bono: 0,
        the18Calificacion: 0,
        the19Viajes: 0,
        the20Rol: "regular",
        the21FechaDeRegistro: DateHelpers.getStartDate(),
        token: "",
        image: "",
        status: "registrado",
        the00isTraveling: false,
        the22Cancelaciones: 0,
        the41SuspendidoPorCancelaciones: false,
        fotoPerfilTomada: false,
        palabraClave: (answer ?? "").trim(),
        preguntaPalabraClave: selectedQuestion ?? "",
        the16CedulaFrontalUsuario: "",
        cedulaFrontalTomada: false,
        the23CedulaReversoUsuario: "",
        cedulaReversoTomada: false,
      );

      try {
        await _clientProvider.create(client);
      } catch (e) {
        // ✅ Rollback si Firestore falla (solo tiene sentido si era nuevo)
        await FirebaseAuth.instance.currentUser?.delete();
        await FirebaseAuth.instance.signOut();

        _progressDialog.hide();
        Snackbar.showSnackbar(
          key.currentContext!,
          'No se pudo completar el registro. Inténtalo nuevamente.',
        );
        return;
      }

      _progressDialog.hide();
      _goTakeFotoPerfil();
    } catch (error) {
      _progressDialog.hide();

      if (kDebugMode) {
        print('Error durante el registro: $error');
      }

      if (error is FirebaseAuthException && error.code == 'email-already-in-use') {
        Snackbar.showSnackbar(
          key.currentContext!,
          'El correo electrónico ya está en uso.',
        );
      } else {
        Snackbar.showSnackbar(
          key.currentContext!,
          'Ocurrió un error durante el registro.',
        );
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
            focusNode: _nameFocusNode,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: questionError != null ? Colors.red : Colors.grey),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedQuestion,
                hint: const Text("Selecciona una pregunta"),
                items: questions.map((value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedQuestion = newValue;
                  });
                },
              ),
            ),
          ),
          if (questionError != null) ...[
            const SizedBox(height: 6),
            Text(questionError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          const SizedBox(height: 16),

          // Respuesta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: answerError != null ? Colors.red : Colors.grey),
              color: Colors.white,
            ),
            child: TextField(
              controller: answerController,
              onChanged: (value) => answer = value,
              decoration: const InputDecoration(
                labelText: "Escribe tu respuesta",
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (answerError != null) ...[
            const SizedBox(height: 6),
            Text(answerError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

}
