import 'dart:async';

import 'package:apptaxis/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:core';

import '../../helpers/DateHelpers.dart';
import '../../helpers/conectivity_service.dart';
import '../../helpers/snackbar.dart';
import '../../providers/client_provider.dart';
import '../../src/colors/colors.dart';
import 'package:apptaxis/models/client.dart';

import '../TakeFotoPerfil/take_foto_perfil_page.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

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

  // Focus
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _apellidosFocusNode = FocusNode();
  final FocusNode _celularFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  // Datos
  String? name;
  String? apellidos;
  String? celular;

  // OTP
  String? _verificationId;
  String? _otpCode;
  bool _otpSent = false;
  bool _otpVerified = false;

  // Pregunta
  String? selectedQuestion;
  String? answer;

  // Errores
  String? nameError;
  String? apellidosError;
  String? celularError;
  String? otpError;
  String? answerError;
  String? questionError;

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController apellidosController = TextEditingController();
  final TextEditingController celularController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController answerController = TextEditingController();

  final List<String> questions = [
    'Nombre de tu mascota',
    'Nombre de tu abuelo materno',
    '¿Cuál es el nombre de tu profesor favorito?',
  ];

  bool _isLoading = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;

  Timer? _resendTimer;
  int _resendSeconds = 0; // 0 = ya puede reenviar
  static const int _resendCooldown = 30; // segundos

  static const int _totalPages = 5; // total pasos = 5 (páginas 0..4)

  bool get _isOtpComplete => (otpController.text.trim().length == 6);

  bool _alreadyRegistered = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _authProvider = MyAuthProvider();
      _clientProvider = ClientProvider();
      _checkConnection();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final existing = await _clientProvider.getById(user.uid);

        // ✅ Si NO hay doc, obligamos OTP de nuevo:
        if (existing == null) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          // se queda en página 0, normal
          return;
        }

        // ✅ Si SÍ hay doc, entonces no debería estar en register realmente,
        // pero por si llega aquí, redirige al flujo normal:
        if (!mounted) return;
        _authProvider.checkIfUserIsLogged(context);
        return;
      }
    });
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();

    setState(() => _resendSeconds = _resendCooldown);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String _maskNumber(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return number;
    // 3001234567 -> 300****567
    return digits.replaceRange(3, digits.length - 3, '****');
  }

  Future<void> _checkConnection() async {
    await connectionService.checkConnectionAndShowCard(context, () {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments as Map?;

    final phone = args?['phone'] as String?;

    if (phone != null && celularController.text.isEmpty) {
      final clean = phone.replaceAll(RegExp(r'\D'), ''); // deja solo dígitos
      final cel10 = clean.startsWith('57') && clean.length >= 12
          ? clean.substring(2) // quita 57 si viene pegado
          : clean;

      celularController.text = cel10;
      celular = cel10; // importante para que tu variable también quede limpia
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    apellidosController.dispose();
    celularController.dispose();
    otpController.dispose();
    answerController.dispose();

    _nameFocusNode.dispose();
    _apellidosFocusNode.dispose();
    _celularFocusNode.dispose();
    _otpFocusNode.dispose();
    _resendTimer?.cancel();
    _deviceBlockTimer?.cancel();

    super.dispose();
  }

  // =========================
  // Helpers OTP
  // =========================
  String _normalizeCel10(String raw) => raw.replaceAll(RegExp(r'\D'), '');
  String _toE164Colombia(String cel10) => '+57$cel10';

  Future<void> _sendOtp() async {
    if (_sendingOtp) return;

    setState(() {
      celularError = null;
      otpError = null;
    });

    final cel10 = _normalizeCel10(celularController.text);
    if (cel10.isEmpty) {
      setState(() => celularError = "Por favor ingresa tu número de celular.");
      return;
    }
    if (cel10.length != 10) {
      setState(() => celularError = "Este número de celular NO es válido.");
      return;
    }

    final hasConnection = await connectionService.hasInternetConnection();
    if (!hasConnection) {
      await alertSinInternet();
      return;
    }

    setState(() => _sendingOtp = true);

    Timer? failSafe;
    void stopLoading() {
      failSafe?.cancel();
      if (mounted) setState(() => _sendingOtp = false);
    }

    // ✅ Si en X segundos no llegó codeSent ni failed, suelta y muestra mensaje
    failSafe = Timer(const Duration(seconds: 25), () {
      if (!mounted) return;
      setState(() {
        _sendingOtp = false;
        otpError = "No pudimos enviar el código. Intenta de nuevo.";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo enviar el código. Revisa tu señal e intenta otra vez."),
          backgroundColor: Colors.red,
        ),
      );
    });

    try {
      final phone = _toE164Colombia(cel10);

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),

        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android puede auto-verificar
          try {
            final cred = await FirebaseAuth.instance.signInWithCredential(credential);
            final user = cred.user;
            if (!mounted || user == null) return;

            stopLoading();

            setState(() {
              _otpVerified = true;
              _otpSent = true;
              otpError = null;
            });

            final redirected = await _redirectIfAlreadyRegistered(user);
            if (redirected) return;

            _goToPage(2);
            _handleFocusForPage(2);
          } catch (_) {
            stopLoading();
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          stopLoading();

          String msg;
          if (e.code == 'too-many-requests') {
            msg = "Por seguridad, se bloqueó temporalmente el envío de códigos en este dispositivo.\nIntenta de nuevo más tarde.";
            _startDeviceBlockCooldown(); // 👇 lo agregamos abajo
          } else {
            msg = e.message ?? "No se pudo enviar el código. Intenta de nuevo.";
          }

          setState(() => otpError = msg);

          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text(msg), backgroundColor: Colors.red),
          // );

          if (kDebugMode) {
            print("❌ verificationFailed: ${e.code} | ${e.message}");
          }
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          stopLoading();

          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            otpError = null;
          });

          _startResendCooldown();
          _goToPage(1);
          _handleFocusForPage(1);
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          stopLoading();

          _verificationId = verificationId;

          if (kDebugMode) {
            print("⏳ codeAutoRetrievalTimeout: $verificationId");
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      stopLoading();

      setState(() => otpError = "Error enviando OTP. Intenta nuevamente.");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(otpError!),
          backgroundColor: Colors.red,
        ),
      );

      if (kDebugMode) {
        print("❌ Exception verifyPhoneNumber: $e");
      }
    }
  }

  Timer? _deviceBlockTimer;
  int _deviceBlockSeconds = 0;
  static const int _deviceBlockCooldown = 120; // 2 min (ajústalo)
  bool get _deviceBlocked => _deviceBlockSeconds > 0;

  void _startDeviceBlockCooldown() {
    _deviceBlockTimer?.cancel();
    setState(() => _deviceBlockSeconds = _deviceBlockCooldown);

    _deviceBlockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_deviceBlockSeconds <= 1) {
        t.cancel();
        setState(() => _deviceBlockSeconds = 0);
      } else {
        setState(() => _deviceBlockSeconds--);
      }
    });
  }



  Future<void> _verifyOtp() async {
    if (_verifyingOtp) return;

    // Limpia error anterior
    setState(() => otpError = null);

    final code = otpController.text.trim();

    // Validaciones rápidas
    if (code.length != 6) {
      setState(() => otpError = "Ingresa el código de 6 dígitos.");
      return;
    }

    if (_verificationId == null) {
      setState(() => otpError = "Primero solicita el código OTP.");
      return;
    }

    setState(() => _verifyingOtp = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;

      if (userCred.user == null) {
        setState(() => otpError = "No se pudo verificar el código.");
        return;
      }

      // ✅ OTP correcto
      setState(() {
        _otpVerified = true;
        _otpCode = code;
        otpError = null;
      });

      final user = userCred.user!;
      final redirected = await _redirectIfAlreadyRegistered(user);
      if (redirected) return;

      // ✅ opcional: mini delay para que el usuario vea el "✅ correcto"
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      // ya verificado, seguimos
      _goToPage(2);
      _handleFocusForPage(2);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        if (e.code == 'invalid-verification-code') {
          otpError = "Código incorrecto. Intenta de nuevo.";
        } else if (e.code == 'session-expired') {
          otpError = "El código expiró. Solicita uno nuevo.";
        } else if (e.code == 'too-many-requests') {
          otpError = "Demasiados intentos. Espera un momento e intenta de nuevo.";
        } else {
          otpError = e.message ?? "No se pudo verificar el código.";
        }
        _otpVerified = false;
      });

    } catch (_) {
      if (!mounted) return;
      setState(() {
        otpError = "No se pudo verificar el código. Intenta de nuevo.";
        _otpVerified = false;
      });
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  Widget _buildPhoneStartPage() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),

          // ✅ Tarjeta superior (look premium)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_android,
                    size: 45,
                    color: Colors.black,
                  ),
                  SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      "Crea tu cuenta con tu número de celular",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                "Te enviaremos un código por mensaje de texto para verificarlo.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ✅ Input celular
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: celularError != null ? Colors.red : Colors.black12),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: Offset(0, 6),
                  color: Color(0x11000000),
                )
              ],
            ),
            child: TextField(
              controller: celularController,
              focusNode: _celularFocusNode,
              enabled: !_sendingOtp,
              onChanged: (value) => celular = value,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                border: InputBorder.none,
                labelText: "Número de celular",
                hintText: "Ingresar número",
                errorText: celularError,
                prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
              ),
            ),
          ),

          const SizedBox(height: 35),

          // ✅ Botón enviar OTP con loader + texto + bloqueo
          OutlinedButton(
            onPressed: (_sendingOtp || _deviceBlocked)
                ? null
                : () async {
              FocusScope.of(context).unfocus();
              await _sendOtp();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primary, width: 1.5), // 👈 borde
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _sendingOtp
                  ? Row(
                key: const ValueKey('sending'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _deviceBlocked
                        ? "Espera ${_deviceBlockSeconds}s"
                        : "Enviando...",
                    style: const TextStyle(
                      color: primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
                  : const Text(
                "Solicitar código",
                key: ValueKey('idle'),
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          if (otpError != null) ...[
            const SizedBox(height: 10),
            Text(
              otpError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 10),

          Text(
            _sendingOtp
                ? "Estamos enviando el código…"
                : "Tu información está protegida. No compartimos tu número.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Future<bool> _redirectIfAlreadyRegistered(User user) async {
    final existing = await _clientProvider.getById(user.uid);

    if (!mounted) return true;

    if (existing != null) {
      setState(() => _alreadyRegistered = true);

      Snackbar.showSnackbar(
        key.currentContext!,
        'Ya tienes cuenta. Ingresando...',
      );

      _authProvider.checkIfUserIsLogged(context);
      return true;
    }

    setState(() => _alreadyRegistered = false);
    return false;
  }

  // =========================
  // Navegación
  // =========================
  Future<void> _goToPage(int page) async {
    if (!mounted) return;

    // 1) suelta teclado/foco antes de cambiar
    FocusScope.of(context).unfocus();

    setState(() => _currentPage = page);

    // 2) espera a que termine la animación del PageView
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );

    // 3) deja que el frame se asiente y luego pide foco
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    _handleFocusForPage(page);
  }

  void _nextPage() async {
    setState(() {
      nameError = null;
      apellidosError = null;
      celularError = null;
      otpError = null;
      answerError = null;
      questionError = null;
    });

    // 0: celular -> enviar otp
    if (_currentPage == 0) {
      await _sendOtp();   // si se envía, _sendOtp() te manda a 1
      return;
    }

    // 1: otp -> verificar
    if (_currentPage == 1) {
      await _verifyOtp(); // si ok, te manda a 2
      return;
    }

    // 2: nombres
    if (_currentPage == 2) {
      if ((name ?? "").trim().isEmpty) {
        setState(() => nameError = "Por favor ingresa tu nombre.");
        return;
      }
      _goToPage(3);
      _handleFocusForPage(3);
      return;
    }

    // 3: apellidos
    if (_currentPage == 3) {
      if ((apellidos ?? "").trim().isEmpty) {
        setState(() => apellidosError = "Por favor ingresa tus apellidos.");
        return;
      }
      _goToPage(4);
      return;
    }

    // 4: pregunta/resp -> registrar
    if (_currentPage == 4) {
      if (selectedQuestion == null) {
        setState(() => questionError = "Debes seleccionar una pregunta.");
        return;
      }
      if ((answer ?? "").trim().isEmpty) {
        setState(() => answerError = "Debes escribir tu respuesta.");
        return;
      }
      _register();
      return;
    }
  }

  void _previousPage() {
    if (_currentPage <= 0) return;
    final prev = _currentPage - 1;
    _goToPage(prev);
    _handleFocusForPage(prev);
  }

  void _handleFocusForPage(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      FocusNode? node;
      switch (page) {
        case 0:
          node = _celularFocusNode;
          break;
        case 1:
          node = _otpFocusNode;
          break;
        case 2:
          node = _nameFocusNode;
          break;
        case 3:
          node = _apellidosFocusNode;
          break;
        default:
          node = null;
      }

      if (node == null) return;

      // truco: unfocus -> pequeño delay -> focus -> show
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;

      FocusScope.of(context).requestFocus(node);
      await Future.delayed(const Duration(milliseconds: 20));
      if (!mounted) return;

      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  // =========================
  // Registro final (Firestore)
  // =========================
  void _register() async {
    // validaciones finales
    setState(() {
      questionError = null;
      answerError = null;

      if (selectedQuestion == null) questionError = "Debes seleccionar una pregunta.";
      if ((answer ?? "").trim().isEmpty) answerError = "Debes escribir tu respuesta.";
    });

    if (questionError != null || answerError != null) return;

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (!_otpVerified || FirebaseAuth.instance.currentUser == null) {
        Snackbar.showSnackbar(key.currentContext!, 'Primero verifica tu número con OTP.');
        return;
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final celNormalizado = _normalizeCel10(celular ?? "");

      // 1) Si ya existe por UID -> entrar
      final existing = await _clientProvider.getById(uid);
      if (existing != null) {
        Snackbar.showSnackbar(key.currentContext!, 'Bienvenido nuevamente 👋');
        if (context.mounted) _authProvider.checkIfUserIsLogged(context);
        return;
      }

      // 2) Evitar duplicado por celular (por si cambian de cuenta)
      final existeCelular = await _clientProvider.existsByCelular(celNormalizado);
      if (existeCelular) {
        Snackbar.showSnackbar(
          key.currentContext!,
          'Este número de celular ya está registrado. Intenta iniciar sesión o recuperar tu cuenta.',
        );
        return;
      }

      // 3) Crear en Firestore
      final client = Client(
        id: uid,
        the01Nombres: name ?? "",
        the02Apellidos: apellidos ?? "",
        the06Email: "", // ✅ ya no usamos correo
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

      await _clientProvider.create(client);
      _goTakeFotoPerfil();
    } catch (e) {
      if (kDebugMode) print('Error durante el registro OTP: $e');
      Snackbar.showSnackbar(key.currentContext!, 'Ocurrió un error durante el registro.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goTakeFotoPerfil() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const TakeFotoPerfil()),
    );
  }

  Future alertSinInternet() {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Sin Internet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          content: const Text('Por favor, verifica tu conexión e inténtalo nuevamente.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final bool disableNext =
        _isLoading || (_currentPage == 1 && (!_isOtpComplete || _verifyingOtp));

    // ✅ Ocultar "Siguiente" en:
    // - Página 0 (celular): siempre
    // - Página 1 (OTP): solo mostrar si OTP ya fue verificado y NO está registrado
    final bool hideNextButton =
        (_currentPage == 0) ||
            (_currentPage == 1 && (!_otpVerified || _alreadyRegistered));

    return Scaffold(
      backgroundColor: blancoCards,
      key: key,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text(
          "Registro",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        actions: const <Widget>[
          Image(
            height: 40.0,
            width: 100.0,
            image: AssetImage('assets/metax_logo.png'),
          )
        ],
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isLoading,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (_currentPage + 1) / _totalPages,
                  backgroundColor: Colors.grey[300],
                  color: primary,
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildPhoneStartPage(), // 0 ✅ celular + enviar otp
                      _buildOtpPage(),        // 1 ✅ confirmar otp + estado
                      _buildNamePage(),       // 2
                      _buildApellidosPage(),  // 3
                      _buildPalabraClave(),   // 4 (registrar)
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
                          onPressed: _isLoading ? null : _previousPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.keyboard_double_arrow_left,
                                  color: Colors.black, size: 16),
                              SizedBox(width: 4),
                              Text("Atrás", style: TextStyle(color: Colors.black)),
                            ],
                          ),
                        ),

                      // ✅ Solo mostramos "Siguiente" cuando corresponda
                      if (!hideNextButton)
                        ElevatedButton(
                          onPressed: disableNext ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _currentPage == 4 ? "Registrar" : "Siguiente",
                                style: const TextStyle(color: Colors.black87),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.double_arrow_rounded,
                                  color: Colors.black, size: 16),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x55000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  // Página Nombres
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
            onChanged: (value) => setState(() => name = value),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: "Nombres",
              errorText: nameError,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // Página Apellidos
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }


  // Página OTP
  Widget _buildOtpPage() {
    final numeroMostrado =
    celularController.text.isEmpty ? "celular" : celularController.text;
    final bool canResend = !_sendingOtp && _resendSeconds == 0;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text(
            "Verifica tu número",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "Ingresa el código de 6 dígitos que enviamos al ${_maskNumber(celularController.text)}.",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black38,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 22),

          // ✅ OTP en cajitas
          PinCodeTextField(
            appContext: context,
            controller: otpController,
            focusNode: _otpFocusNode,
            autoFocus: false,
            length: 6,
            keyboardType: TextInputType.number,
            autoDisposeControllers: false,
            enableActiveFill: true,
            animationType: AnimationType.fade,
            animationDuration: const Duration(milliseconds: 180),
            cursorColor: primary,
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
            pastedTextStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            beforeTextPaste: (text) => true,

            // ✅ Limpia error al escribir
            onChanged: (value) {
              setState(() {
                _otpCode = value;
                otpError = null;
                _otpVerified = false;
              });
            },

            // ✅ Si quieres que al completar dispare verificación automáticamente:
            onCompleted: (value) async {
              // opcional: verifica apenas complete
              await _verifyOtp();
            },

            // ✅ Tema visual (cajitas)
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(12),
              fieldHeight: 54,
              fieldWidth: 46,
              activeColor: primary,
              selectedColor: primary,
              inactiveColor: Colors.black12,
              activeFillColor: Colors.white,
              selectedFillColor: Colors.white,
              inactiveFillColor: Colors.white,
              borderWidth: 1.2,
            ),

            // ✅ Loader (mientras verifica)
            enabled: !_verifyingOtp,
          ),

          const SizedBox(height: 10),

          // 🔄/❌/✅ Estado
          if (_verifyingOtp)
            const Text(
              "Verificando código...",
              style: TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),

          if (otpError != null && !_verifyingOtp)
            Text(
              otpError!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),

          if (_otpVerified)
            const Text(
              "✅ Código correcto",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w800,
              ),
            ),

          const SizedBox(height: 12),

          // 🔁 Reenviar
          TextButton(
            onPressed: canResend ? _sendOtp : null,
            child: _sendingOtp
                ? const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(
              _resendSeconds > 0
                  ? "Reenviar en ${_resendSeconds}s"
                  : "Reenviar código",
            ),
          ),
        ],
      ),
    );
  }

  // Tu página de pregunta/clave (sin cambios grandes)
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
                  setState(() => selectedQuestion = newValue);
                },
              ),
            ),
          ),
          if (questionError != null) ...[
            const SizedBox(height: 6),
            Text(questionError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          const SizedBox(height: 16),

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