import 'package:apptaxis/Pages/email_verification_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Pages/Forgot_PasswordPage/forgot_password_page.dart';
import 'Pages/Login_page/login_page.dart';
import 'Pages/Register_page/register_page.dart';
import 'Pages/Splash_page/splash.dart';
import 'Pages/TakeFotoPerfil/take_foto_perfil_page.dart';
import 'Pages/bloqueo_page/bloqueo_page.dart';
import 'Pages/compartir_aplicacion_page/View/compartir_aplicacion_page.dart';
import 'Pages/contactanos_page/View/contactanos_page.dart';
import 'Pages/detail_history_page/detail_history_page.dart';
import 'Pages/eliminar_Cuenta_page/eliminar_cuenta_page.dart';
import 'Pages/historial_viajes_page/View/historial_viajes_page.dart';
import 'Pages/map_client_page/map_client_page.dart';
import 'Pages/politicas_de_privacidad_page/View/politicas_de_privacidad.dart';
import 'Pages/profile_page/profile_page.dart';
import 'Pages/travel_calification_page/View/travel_calification_page.dart';
import 'Pages/travel_info_page/travel_info_page.dart';
import 'Pages/travel_map_page/View/travel_map_page.dart';
import 'firebase_options.dart';
import 'src/colors/colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Asegura que Flutter esté inicializado antes de cargar otros recursos
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno del archivo .env
  await dotenv.load(fileName: ".env");

  // Establecer la orientación preferida
  await _setPreferredOrientations();

  // Configurar estilo de la barra de estado
  _setSystemUIOverlayStyle();

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Correr la aplicación
  runApp(const MyApp());
}

Future<void> _setPreferredOrientations() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

void _setSystemUIOverlayStyle() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Metax Cliente",
      initialRoute: "splash"
          "",
      routes: {
        'splash': (BuildContext context) => const SplashPage(),
        'login': (BuildContext context) => const LoginPage(),
        'register': (BuildContext context) => const RegisterPage(),
        'take_foto_perfil': (BuildContext context) => const TakeFotoPerfil(),
        'email_verification': (BuildContext context) => const EmailVerificationPage(),
        'map_client': (BuildContext context) => const MapClientPage(),
        'forgot_password': (BuildContext context) => const ForgotPage(),
        'travel_info_page': (BuildContext context) => const ClientTravelInfoPage(),
        'travel_map_page': (BuildContext context) => const TravelMapPage(),
        'bloqueo_page': (BuildContext context) =>  const PaginaDeBloqueo(),
        'compartir_aplicacion': (BuildContext context) => const CompartirAplicacionpage(),
        'profile': (BuildContext context) => const ProfilePage(),
        'contactanos': (BuildContext context) => const ContactanosPage(),
        'politicas_de_privacidad': (BuildContext context) => const PoliticasDePrivacidadPage(),
        'historial_viajes': (BuildContext context) => const HistorialViajesPage(),
        'eliminar_cuenta': (BuildContext context) => const EliminarCuentaPage(),
        'travel_calification_page': (BuildContext context) => const TravelCalificationPage(),
        'detail_history_page': (BuildContext context) => const DetailHistoryPage(),

      },
      theme: ThemeData(
        scaffoldBackgroundColor: blancoCards,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English, no country code
        Locale('es', ''), // Spanish, no country code
      ],
    );
  }
}
