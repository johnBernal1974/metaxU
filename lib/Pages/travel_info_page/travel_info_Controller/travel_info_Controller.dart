
import 'dart:async';
import 'dart:math';
import 'package:apptaxis/helpers/conectivity_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/client_provider.dart';
import '../../../../providers/geofire_provider.dart';
import '../../../../providers/push_notifications_provider.dart';
import '../../../models/driver.dart';
import '../../../models/price.dart';
import '../../../models/travel_info.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/price_provider.dart';
import '../../../providers/travel_info_provider.dart';
import 'package:apptaxis/models/client.dart';
import 'package:apptaxis/utils/utilsMap.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../travel_map_page/View/travel_map_page.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math' as math;



class TravelInfoController{
  late BuildContext context;
  late PricesProvider _pricesProvider;
  late TravelInfoProvider _travelInfoProvider;
  late MyAuthProvider _authProvider;
  late DriverProvider _driverProvider;
  late GeofireProvider _geofireProvider;
  late PushNotificationsProvider _pushNotificationsProvider;
  late ClientProvider _clientProvider;
  Client? client;
  String? apuntesAlConductor;
  late Function refresh;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  late Completer<GoogleMapController> _mapController = Completer();
  CameraPosition initialPosition = const CameraPosition(
    target: LatLng(4.1461765, -73.641138),
    zoom: 12.0,
  );
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  late String from = "";
  late String to = "";
  late LatLng fromLatlng;
  late LatLng toLatlng;
  LatLngBounds? bounds;
  Set<Polyline> polylines = {};
  List<LatLng> points = List.from([]);
  late BitmapDescriptor fromMarker;
  late BitmapDescriptor toMarker;
  String? min;
  String? km;
  double? total;
  int? totalInt;
  double? radioDeBusqueda;
  int distancia = 0;
  String distanciaString = '';
  int duracion = 0;
  String duracionString = '';
  double tiempoEnMinutos = 0;
  List<String> nearbyDrivers = [];
  List<String> nearbyMotorcyclers = [];
  StreamSubscription<List<DocumentSnapshot>>? _streamSubscription;
  StreamSubscription<DocumentSnapshot<Object?>>? _clientInfoSuscription;
  StreamSubscription<DocumentSnapshot<Object?>>? _streamStatusSuscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isSendingNotification = false; // Indicador para controlar el envío de notificaciones
  Set<String> notifiedDrivers = <String>{};
  Position? _position;
  bool serviceAccepted = false; // Bandera global para detener notificaciones
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Cambio a Api desde el backend
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  //para internet
  final ConnectionService connectionService = ConnectionService();

  int contadorApi = 0;

  StreamSubscription? _streamSubscriptionPorteria;

  String? requestId;

  Timer? _timeoutBusqueda;

  DateTime? _deadlineBusqueda;

  bool _isSendingNotifications = false;

  String tipoServicioSolicitado = "";

  bool _permitirStandard = false;

  bool yaIntentoTodosLosVIP = false;

  double _radioActual = 0.0;
  double _radioMaximo = 1.0;
  Timer? _timerExpansion;


  // ✅ listo solo si ya hay ruta y tarifa
  bool get canConfirmTrip {
    final hasRoute = (points.length > 1) || polylines.isNotEmpty;
    final hasFare = (total != null) && (total! > 0);
    return hasRoute && hasFare;
  }

  bool get isCalculatingTrip => !canConfirmTrip;

  Map<String, Map<String, dynamic>> vehiculosCache = {};


  Future<void> init(BuildContext context, Function refresh) async {
    print('🔥 INIT EJECUTADO');
    this.context = context;
    this.refresh = refresh;

    resetVisualTrip();

    _pricesProvider = PricesProvider();
    _travelInfoProvider = TravelInfoProvider();
    _driverProvider = DriverProvider();
    _authProvider = MyAuthProvider();
    _clientProvider = ClientProvider();
    _geofireProvider = GeofireProvider();
    _pushNotificationsProvider = PushNotificationsProvider();

    // Reinicia el Completer del controlador de mapa cada vez que se llama init
    //_mapController = Completer();

    Map<String, dynamic>? arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    await getClientInfo();
    if (arguments != null) {
      from = arguments['from'] ?? "Desconocido";
      to = arguments['to'] ?? "Desconocido";
      fromLatlng = arguments['fromlatlng'];
      toLatlng = arguments['tolatlng'];

      // ✅ Todo lo que requiere internet va aquí
      if(context.mounted){
        await connectionService.checkConnectionAndShowCard(context, () {
          // No pongas await aquí porque el callback es VoidCallback
          Future.microtask(() async {
            updateMap();
            animateCameraToPosition(fromLatlng.latitude, fromLatlng.longitude);
            print('🚀 init() está llamando getGoogleMapsDirections');
            await getGoogleMapsDirections(fromLatlng, toLatlng);
          });
        });
      }
    } else {
      if (kDebugMode) {
        print('Error: Los argumentos son nulos');
      }
    }
  }


  // INIT SOLO PARA PORTERIA
  void initPorteria(BuildContext context, Function refresh) {
    this.context = context;
    this.refresh = refresh;

    _geofireProvider = GeofireProvider();
    _pricesProvider = PricesProvider();
    _driverProvider = DriverProvider();

    _authProvider = MyAuthProvider();
    _pushNotificationsProvider = PushNotificationsProvider();
    _travelInfoProvider = TravelInfoProvider();
  }


  void dispose() {
    _streamSubscription?.cancel();
    _clientInfoSuscription?.cancel();
    _streamStatusSuscription?.cancel();
    clearApuntesAlConductor();
    _audioPlayer.dispose();
    km = null;
    min = null;
    total = 0.0;
  }

  Future<void> fitRouteToScreen() async {
    if (!_mapController.isCompleted) return;

    try {
      final controller = await _mapController.future;

      // ✅ Altura real del MAPA (tu mapa ocupa 50% pantalla)
      final mapHeight = MediaQuery.of(context).size.height * 0.50;

      // ✅ 1) Si la distancia es MUY corta → mejor zoom al centro (evita marcadores pegados)
      final distanceMeters = _calculateDistance(fromLatlng, toLatlng); // metros

      if (distanceMeters < 900000) { // 👈 ajusta 150/200/300 a tu gusto
        final center = LatLng(
          (fromLatlng.latitude + toLatlng.latitude) / 2,
          (fromLatlng.longitude + toLatlng.longitude) / 2,
        );

        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(center, 17.0), // 👈 16.5 - 18.0 recomendado
        );

        // ✅ opcional: sube un poquito para que no quede "pegado abajo"
        await controller.animateCamera(
          CameraUpdate.scrollBy(0, -(mapHeight * 0.12)),
        );
        return;
      }

      // ✅ 2) Para distancias normales/largas → bounds con ajustes verticales (tu lógica)
      final swLat0 = math.min(fromLatlng.latitude, toLatlng.latitude);
      final swLng0 = math.min(fromLatlng.longitude, toLatlng.longitude);
      final neLat0 = math.max(fromLatlng.latitude, toLatlng.latitude);
      final neLng0 = math.max(fromLatlng.longitude, toLatlng.longitude);

      double swLat = swLat0, swLng = swLng0, neLat = neLat0, neLng = neLng0;

      final lngSpan = (neLng - swLng).abs();
      final latSpan = (neLat - swLat).abs();

      // ✅ Si la ruta es MUY vertical, agranda el ancho
      if (lngSpan < 0.002 || (latSpan > 0 && (lngSpan / latSpan) < 0.15)) {
        final extra = 0.005; // ajusta: 0.003 a 0.01 según tu ciudad/zoom
        swLng -= extra;
        neLng += extra;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(swLat, swLng),
        northeast: LatLng(neLat, neLng),
      );

      final padding = (mapHeight * 0.12); // px
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));

      // ✅ Scroll hacia arriba para compensar UI / sensación "pegado abajo"
      final yOffset = (mapHeight * 0.18);
      await controller.animateCamera(CameraUpdate.scrollBy(0, -yOffset));

    } catch (e) {
      if (kDebugMode) print('fitRouteToScreen error: $e');
    }
  }



  Future<void> updateMap() async {
    clearMap();
    // Crea o actualiza los marcadores
    fromMarker = await createMarkerImageFromAssets('assets/ubicacion_client.png');
    toMarker = await createMarkerImageFromAssets('assets/marker_destino.png');
    addMarker('from', fromLatlng.latitude, fromLatlng.longitude, 'Origen', '', fromMarker);
    addMarker('to', toLatlng.latitude, toLatlng.longitude, 'Destino', '', toMarker);
    // Crear los límites para incluir ambos marcadores
    LatLngBounds bounds = LatLngBounds(
      northeast: LatLng(
        fromLatlng.latitude > toLatlng.latitude ? fromLatlng.latitude : toLatlng.latitude,
        fromLatlng.longitude > toLatlng.longitude ? fromLatlng.longitude : toLatlng.longitude,
      ),
      southwest: LatLng(
        fromLatlng.latitude < toLatlng.latitude ? fromLatlng.latitude : toLatlng.latitude,
        fromLatlng.longitude < toLatlng.longitude ? fromLatlng.longitude : toLatlng.longitude,
      ),
    );
    // Ajustar los límites con un margen extra
    bounds = _extendBounds(bounds, fromLatlng);
    bounds = _extendBounds(bounds, toLatlng);
    // Ajustar la cámara del mapa a los límites calculados
    if(context.mounted){
      await fitBounds(bounds, context);
    }

  }
  void clearMap() {
    polylines.clear(); // Limpia todas las polilíneas actuales
    markers.clear();   // Limpia todos los marcadores actuales
  }

  void addMarker(String markerId, double lat, double lng, String title, String content, BitmapDescriptor iconMarker) {
    MarkerId id = MarkerId(markerId);
    Marker marker = Marker(
      markerId: id,
      icon: iconMarker,
      position: LatLng(lat, lng),
      anchor: const Offset(0.5, 0.5),
      infoWindow: InfoWindow(title: title, snippet: content),
    );
    // Añade el marcador al mapa
    markers[id] = marker;
  }


  LatLngBounds _extendBounds(LatLngBounds? bounds, LatLng newPoint) {
    if (bounds == null) {
      return LatLngBounds(northeast: newPoint, southwest: newPoint);
    }
    double minLat = bounds.southwest.latitude < newPoint.latitude ? bounds.southwest.latitude : newPoint.latitude;
    double minLng = bounds.southwest.longitude < newPoint.longitude ? bounds.southwest.longitude : newPoint.longitude;
    double maxLat = bounds.northeast.latitude > newPoint.latitude ? bounds.northeast.latitude : newPoint.latitude;
    double maxLng = bounds.northeast.longitude > newPoint.longitude ? bounds.northeast.longitude : newPoint.longitude;
    const double margin = 0.002; // Ajustar el margen según sea necesario
    return LatLngBounds(
      southwest: LatLng(minLat - margin, minLng - margin),
      northeast: LatLng(maxLat + margin, maxLng + margin),
    );
  }


  // Método para calcular la distancia entre dos LatLng
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371e3; // En metros
    double lat1 = point1.latitude * (3.14159265359 / 180);
    double lat2 = point2.latitude * (3.14159265359 / 180);
    double deltaLat = (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    double deltaLng = (point2.longitude - point1.longitude) * (3.14159265359 / 180);
    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) *
            sin(deltaLng / 2) * sin(deltaLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c; // Distancia en metros
  }

  Future<void> fitBounds(LatLngBounds bounds, BuildContext context) async {
    if (!context.mounted) return;

    await runAfterMapReady((c) async {
      final padding = MediaQuery.of(context).size.height * 0.1;
      await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
    });
  }

  Future<GoogleMapController?> _waitMapController({int msTimeout = 2500}) async {
    final sw = Stopwatch()..start();

    while (!_mapController.isCompleted && sw.elapsedMilliseconds < msTimeout) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!_mapController.isCompleted) return null;
    return _mapController.future;
  }


  void guardarTipoServicio(String tipoServicio) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('tipoServicio', tipoServicio);
  }


  void guardarApuntesConductor(String apuntes) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('apuntes_al_conductor', apuntes);
    apuntesAlConductor = apuntes;
  }

  void clearApuntesAlConductor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('apuntes_al_conductor', "");
    // Actualizar la variable en la memoria
    apuntesAlConductor = "";
  }

  Future<void> deleteTravelInfo() async {
    try {
      // Obtener el ID del cliente actual
      String currentUserId = _authProvider.getUser()!.uid;

      // Obtener el documento del viaje usando el ID del cliente
      DocumentSnapshot travelInfoSnapshot = await _firestore.collection('TravelInfo').doc(currentUserId).get();

      // Verificar si el documento existe
      if (travelInfoSnapshot.exists) {
        // Hacer un casting del resultado a Map<String, dynamic>
        Map<String, dynamic> travelInfoData = travelInfoSnapshot.data() as Map<String, dynamic>;

        // Obtener el estado del viaje
        String status = travelInfoData['status'] ?? '';

        // Verificar si el estado es 'created'
        if (status == 'created') {
          // Borrar el documento
          await _firestore.collection('TravelInfo').doc(currentUserId).delete();
        }
      } else {
        if (kDebugMode) {
          print('El documento no existe.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al borrar el documento: $e');
      }
    }
  }


  Future<void> getClientInfo() async {
    final user = _authProvider.getUser();
    if (user != null) {
      final userId = user.uid;
      Stream<DocumentSnapshot> clientStream = _clientProvider.getByIdStream(userId);
      _clientInfoSuscription = clientStream.listen((DocumentSnapshot document) {
        if (document.exists) {
          client = Client.fromJson(document.data() as Map<String, dynamic>);
          refresh();
        } else {
          if (kDebugMode) {
            print('Error: El documento del cliente no existe.');
          }
        }
      }, onError: (error) {
        if (kDebugMode) {
          print('Error al escuchar los cambios en la información del cliente: $error');
        }
      });
    } else {
      if (kDebugMode) {
        print('Error: Usuario no autenticado.');
      }
    }
  }

  void onMapCreated(GoogleMapController controller) async {
    controller.setMapStyle(utilsMap.mapStyle);

    // ✅ si ya había uno, resetea y guarda el nuevo controller
    if (_mapController.isCompleted) {
      _mapController = Completer<GoogleMapController>();
    }
    _mapController.complete(controller);

    if (kDebugMode) {
      print('🗺️ MAP CREADO NUEVO controller: ${DateTime.now()}');
    }
  }


  Future<void> getGoogleMapsDirections(LatLng from, LatLng to) async {
    contadorApi++;
    print('🧮 API getDirections llamada #$contadorApi | ${DateTime.now()}');
    print('🟢 LLAMANDO API getDirections');
    print('FROM: ${from.latitude}, ${from.longitude}');
    print('TO: ${to.latitude}, ${to.longitude}');
    print('TIMESTAMP: ${DateTime.now()}');
    final ok = await connectionService.hasInternetConnection();
    if (!ok) return;
    try {
      final res = await _functions.httpsCallable('getDirections').call({
        'fromLat': from.latitude,
        'fromLng': from.longitude,
        'toLat': to.latitude,
        'toLng': to.longitude,
        'mode': 'driving',
      });

      final data = Map<String, dynamic>.from(res.data);
      print('✅ RESPUESTA API OK');

      if (data['ok'] != true) {
        if (kDebugMode) print('getDirections failed: $data');
        return;
      }

      final String polylineEncoded = (data['polyline'] ?? '').toString();
      final int distanceMeters = (data['distanceMeters'] ?? 0) as int;
      final int durationSeconds = (data['durationSeconds'] ?? 0) as int;

      // ✅ Actualiza variables que ya usas
      distancia = distanceMeters;
      duracion = durationSeconds;
      tiempoEnMinutos = durationSeconds / 60.0;

      // Formatos tipo “X km” y “Y min”
      final double kmValue = distanceMeters / 1000.0;
      km = '${kmValue.toStringAsFixed(1)} km';

      final int minsValue = (durationSeconds / 60).round();
      min = '$minsValue min';

      distanciaString = km ?? '';
      duracionString = min ?? '';

      // ✅ Calcula tarifa y radio (igual que hoy)
      calcularPrecio();
      obtenerRadiodeBusqueda();

      // ✅ Dibuja polyline usando el encoded
      await setPolylinesFromEncoded(polylineEncoded);

    } catch (e) {
      if (kDebugMode) print('getGoogleMapsDirections (via function) error: $e');
    }
  }

  Future<void> runAfterMapReady(Future<void> Function(GoogleMapController c) action) async {
    // Espera a que el mapa se cree
    final controller = await _waitMapController(msTimeout: 6000);
    if (controller == null) {
      if (kDebugMode) print('❌ runAfterMapReady: controller null');
      return;
    }

    // Espera al primer frame + un tick
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await action(controller);
    } catch (e) {
      if (kDebugMode) print('❌ runAfterMapReady error: $e');
    }
  }

  Future<void> setPolylinesFromEncoded(String encodedPolyline) async {
    clearMap();
    print('🧭 Dibujando polylines');
    final decoded = PolylinePoints().decodePolyline(encodedPolyline);
    points = decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();

    polylines.clear();
    polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.black,
        points: points,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );

    // Marcadores
    addMarker('from', fromLatlng.latitude, fromLatlng.longitude, 'Origen', '', fromMarker);
    addMarker('to', toLatlng.latitude, toLatlng.longitude, 'Destino', '', toMarker);

    refresh();

    // ✅ AHORA sí: encuadra ruta completa
    await Future.delayed(const Duration(milliseconds: 50)); // pequeño “tick” para evitar glitch
    await fitRouteToScreen();
  }


  void resetVisualTrip() {
    markers.clear();
    polylines.clear();
    points = [];
    km = null;
    min = null;
    total = null;
    totalInt = null;
    distancia = 0;
    duracion = 0;
    distanciaString = '';
    duracionString = '';
    // 👇 importante: repinta de inmediato para borrar lo anterior
    refresh();
  }



  void calcularPrecio() async {
    try {
      final Price price = await _pricesProvider.getAll();

      // ✅ Rol del usuario (por defecto regular)
      final rol = (client?.rol ?? 'regular').toLowerCase().trim();

      // ✅ Valores según rol
      final double valorKm = (rol == 'hotel')
          ? price.theValorKmHotel
          : (rol == 'turismo')
          ? price.theValorKmTurismo
          : price.theValorKmRegular;

      final double valorMin = (rol == 'hotel')
          ? price.theValorMinHotel
          : (rol == 'turismo')
          ? price.theValorMinTurismo
          : price.theValorMinRegular;

      final double tarifaMinima = (rol == 'hotel')
          ? price.theTarifaMinimaHotel.toDouble()
          : (rol == 'turismo')
          ? price.theTarifaMinimaTurismo.toDouble()
          : price.theTarifaMinimaRegular.toDouble();

      // ✅ Declara estas variables (antes no estaban y por eso fallaba)
      double valorKilometro = 0.0;
      double valorMinuto = 0.0;

      // --------- KM ---------
      if (km != null) {
        final double distanciaKm =
        double.parse(km!.split(" ")[0].replaceAll(',', ''));

        // 👇 aquí usas el valorKm del rol (NO el regular)
        valorKilometro = distanciaKm * valorKm;

        // Incrementos según distancia (se aplican igual)
        if (distanciaKm > 100) {
          valorKilometro *= 2.00;
        } else if (distanciaKm > 80) {
          valorKilometro *= 1.80;
        } else if (distanciaKm > 50) {
          valorKilometro *= 1.50;
        } else if (distanciaKm > 40) {
          valorKilometro *= 1.40;
        } else if (distanciaKm > 30) {
          valorKilometro *= 1.30;
        } else if (distanciaKm > 20) {
          valorKilometro *= 1.20;
        }
      }

      // --------- MIN ---------
      if (min != null) {
        final double minutos =
        double.parse(min!.split(" ")[0].replaceAll(',', ''));

        // 👇 aquí usas el valorMin del rol (NO el regular)
        valorMinuto = minutos * valorMin;
      }

      // ✅ Total con dinámica
      total = (valorMinuto + valorKilometro) * price.theDinamica;

      // ✅ Redondeo
      total = redondearACentena(total);

      // ✅ Mínima según rol (NO redeclarar)
      total = total?.clamp(tarifaMinima, double.infinity);

      totalInt = total?.toInt();
      refresh();
    } catch (e) {
      if (kDebugMode) {
        print('Error al calcular el precio: $e');
      }
    }
  }


  // new para ajustar roles y tarifas del rol del usuario

  String _rolUsuario() {
    return (client?.rol ?? 'regular').toLowerCase();
  }

  double _valorKmPorRol(Price price) {
    switch (_rolUsuario()) {
      case 'hotel':
        return price.theValorKmHotel;
      case 'turismo':
        return price.theValorKmTurismo;
      default:
        return price.theValorKmRegular;
    }
  }

  double _valorMinPorRol(Price price) {
    switch (_rolUsuario()) {
      case 'hotel':
        return price.theValorMinHotel;
      case 'turismo':
        return price.theValorMinTurismo;
      default:
        return price.theValorMinRegular;
    }
  }

  double _tarifaMinimaPorRol(Price price) {
    switch (_rolUsuario()) {
      case 'hotel':
        return price.theTarifaMinimaHotel.toDouble();
      case 'turismo':
        return price.theTarifaMinimaTurismo.toDouble();
      default:
        return price.theTarifaMinimaRegular.toDouble();
    }
  }

  void obtenerRadiodeBusqueda() async {
    try {
      Price price = await _pricesProvider.getAll();
      radioDeBusqueda = price.theRadioDeBusqueda;
      if (kDebugMode) {
        print("**************************Radio de busqueda: $radioDeBusqueda **************************");
      }
      refresh();
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener el radio de busqueda: $e');
      }
    }
  }

  double? redondearACentena(double? valor) {
    if (valor == null) return null;
    return (valor / 100).ceil() * 100.toDouble();
  }

  Future<void> animateCameraToPosition(double latitude, double longitude) async {
    await runAfterMapReady((c) async {
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            bearing: 0,
            target: LatLng(latitude, longitude),
            zoom: 15,
          ),
        ),
      );
    });
  }

  Future<BitmapDescriptor> createMarkerImageFromAssets(String path) async {
    try {
      ImageConfiguration configuration = const ImageConfiguration();
      BitmapDescriptor bitmapDescriptor = await BitmapDescriptor.fromAssetImage(configuration, path);
      return bitmapDescriptor;
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar la imagen del marcador: $e');
      }
      return BitmapDescriptor.defaultMarker;
    }
  }

  String formatDuration(String durationText) {
    List<String> parts = durationText.split(' ');
    List<String> formattedParts = parts.map((part) {
      switch (part) {
        case 'hours':
          return 'h';
        case 'hour':
          return 'hs';
        case 'mins':
          return 'mins';
        case 'min':
          return 'min';
        default:
          return part;
      }
    }).toList();
    return formattedParts.join(' ');
  }

  String? extractCity(String? fullAddress) {
    if (fullAddress != null) {
      List<String> addressParts = fullAddress.split(',');
      if (addressParts.isNotEmpty) {
        return addressParts[1].trim();
      }
    }
    return null;
  }

  ///marca para saber si se hizo el rebase

  void getNearbyDrivers() {

    _permitirStandard = false;

    /// 🔥 RESET SOLO AL INICIO
    nearbyDrivers.clear();
    notifiedDrivers.clear();
    _isSendingNotifications = false;

    serviceAccepted = false;

    _deadlineBusqueda = DateTime.now().add(const Duration(seconds: 60));

    /// 🔥 cancelar suscripción y timer anteriores
    _streamSubscription?.cancel();
    _timerExpansion?.cancel();

    /// 🔥 iniciar radio base (el mismo del mapa)
    _radioActual = radioDeBusqueda ?? 0.5;

    _buscarConductores();
  }

  void _buscarConductores() {

    if (_radioActual > _radioMaximo) {
      print("🚫 Se alcanzó el radio máximo");
      return;
    }

    print("📡 Buscando conductores con radio: $_radioActual km");

    _streamSubscription?.cancel();

    Stream<List<DocumentSnapshot>> stream = _geofireProvider.getNearbyDrivers(
      fromLatlng.latitude,
      fromLatlng.longitude,
      _radioActual,
    );

    _streamSubscription = stream.listen((List<DocumentSnapshot> documentList) async {

      /// 🔥 STOP GLOBAL
      if (_tiempoAgotado() || serviceAccepted) {
        print("⛔ STOP listener NORMAL");
        return;
      }

      /// 🔥 EVITAR múltiples ejecuciones
      if (_isSendingNotifications) {
        print("⛔ Envío en progreso (NORMAL)");
        return;
      }

      List<String> driversFiltrados = [];

      // for (DocumentSnapshot d in documentList) {
      //   try {
      //     Map<String, dynamic> positionData = d.get('position');
      //
      //     if (positionData.containsKey('geopoint')) {
      //       GeoPoint geoPoint = positionData['geopoint'];
      //
      //       double distanceInMeters = Geolocator.distanceBetween(
      //         fromLatlng.latitude,
      //         fromLatlng.longitude,
      //         geoPoint.latitude,
      //         geoPoint.longitude,
      //       );
      //
      //       double distanceInKm = distanceInMeters / 1000;
      //
      //       print("🚗 Driver ${d.id} a ${distanceInKm.toStringAsFixed(2)} km");
      //
      //       /// 🔥 FILTRO REAL
      //       if (distanceInKm <= _radioActual) {
      //         driversFiltrados.add(d.id);
      //       }
      //     }
      //   } catch (e) {
      //     print("⚠️ Error driver ${d.id}: $e");
      //   }
      // }26 abril 2026 - para filtrar los no activos antes de enviar notificaciones

      for (DocumentSnapshot d in documentList) {
        try {
          Map<String, dynamic> data = d.data() as Map<String, dynamic>;

          /// 🔥 NUEVO FILTRO (USANDO TU updatedAt)
          if (!estaActivoRecientementeDesdeLocation(data)) {
            print("⛔ Driver ${d.id} sin ubicación reciente, saltando...");
            continue;
          }

          Map<String, dynamic> positionData = d.get('position');

          if (positionData.containsKey('geopoint')) {
            GeoPoint geoPoint = positionData['geopoint'];

            double distanceInMeters = Geolocator.distanceBetween(
              fromLatlng.latitude,
              fromLatlng.longitude,
              geoPoint.latitude,
              geoPoint.longitude,
            );

            double distanceInKm = distanceInMeters / 1000;

            print("🚗 Driver ${d.id} a ${distanceInKm.toStringAsFixed(2)} km");

            if (distanceInKm <= _radioActual) {
              driversFiltrados.add(d.id);
            }
          }

        } catch (e) {
          print("⚠️ Error driver ${d.id}: $e");
        }
      }

      /// 🔥 SOLO nuevos
      List<String> nuevosDrivers = driversFiltrados
          .where((id) => !notifiedDrivers.contains(id))
          .toList();

      // 🔥 REEMPLAZAR lista completa por solo los activos actuales
      nearbyDrivers = driversFiltrados;

      if (nuevosDrivers.isEmpty) {

        print("⏳ No hay conductores, ampliando radio...");

        /// 🔥 aumentar 100 metros
        _radioActual += 0.1;

        _timerExpansion?.cancel();
        _timerExpansion = Timer(const Duration(seconds: 2), () {
          _buscarConductores();
        });

        return;
      }

      print("🆕 Conductores encontrados: ${nuevosDrivers.length}");

      /// 🔥 precargar vehículos
      for (String driverId in nuevosDrivers) {
        try {
          Driver? driver = await _driverProvider.getById(driverId);

          if (driver == null || driver.vehiculoActivoId.isEmpty) continue;

          if (!vehiculosCache.containsKey(driverId)) {
            final doc = await FirebaseFirestore.instance
                .collection('Drivers')
                .doc(driverId)
                .collection('vehiculos')
                .doc(driver.vehiculoActivoId)
                .get();

            if (doc.exists) {
              vehiculosCache[driverId] = doc.data()!;
            }
          }
        } catch (e) {
          print("Error precargando vehículo: $e");
        }
      }

      // 🔥 eliminar conductores que ya no están activos
      nearbyDrivers = nearbyDrivers.where((driverId) {
        return nuevosDrivers.contains(driverId);
      }).toList();

      //nearbyDrivers.addAll(nuevosDrivers);

      _isSendingNotifications = true;

      try {
        await _attemptToSendNotification(
          nearbyDrivers,
          notifiedDrivers.length,
        );
      } catch (e) {
        print("Error en envío NORMAL: $e");
      }

      _isSendingNotifications = false;

    });
  }

  bool _tiempoAgotado() {
    if (_deadlineBusqueda == null) return true;
    return DateTime.now().isAfter(_deadlineBusqueda!);
  }



  void getNearbyDriversPorteria() {

    serviceAccepted = false;

    /// 🔥 RESET SOLO AL INICIO (CLAVE)
    nearbyDrivers.clear();
    notifiedDrivers.clear();
    _isSendingNotifications = false;

    _deadlineBusqueda = DateTime.now().add(const Duration(seconds: 60));

    /// cancelar timeout anterior
    _timeoutBusqueda?.cancel();

    /// timeout de búsqueda
    _timeoutBusqueda = Timer(const Duration(seconds: 60), () async {

      print("⛔ Tiempo agotado TOTAL");

      _streamSubscriptionPorteria?.cancel();

      if (requestId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection("TravelRequests")
          .doc(requestId)
          .get();

      if (!doc.exists) return;

      final status = doc.data()?["status"];

      if (
      status == "accepted" ||
          status == "driver_on_the_way" ||
          status == "driver_is_waiting" ||
          status == "started"
      ) {
        return;
      }

      if (status == "created") {
        await FirebaseFirestore.instance
            .collection("TravelRequests")
            .doc(requestId)
            .update({
          "status": "no_driver_found"
        });
      }

      /// 🔥 limpiar SOLO al final
      notifiedDrivers.clear();
    });

    /// buscar conductores cercanos
    Stream<List<DocumentSnapshot>> stream = _geofireProvider.getNearbyDrivers(
      fromLatlng.latitude,
      fromLatlng.longitude,
      radioDeBusqueda ?? 1,
    );

    _streamSubscriptionPorteria =
        stream.listen((List<DocumentSnapshot> documentList) async {

          /// 🔥 STOP GLOBAL
          if (_tiempoAgotado() || serviceAccepted) {
            print("⛔ STOP listener porteria");
            return;
          }

          /// 🔥 evitar múltiples ejecuciones
          if (_isSendingNotifications) {

            print("⏳ Envío en progreso, agregando a cola");

            /// 🔥 SOLO agregar nuevos, NO ejecutar envío aún
            List<String> driversStream =
            documentList.map((d) => d.id).toList();

            List<String> nuevosDrivers = driversStream
                .where((id) => !notifiedDrivers.contains(id))
                .toList();

            if (nuevosDrivers.isNotEmpty) {
              print("🆕 (cola) nuevos conductores: ${nuevosDrivers.length}");
              nearbyDrivers.addAll(nuevosDrivers);
            }

            return;
          }

          if (documentList.isEmpty) {
            print("PORTERIA no encontró taxis en este momento");
            return;
          }

          /// 🔥 IDs actuales
          List<String> driversStream =
          documentList.map((d) => d.id).toList();

          /// 🔥 SOLO nuevos
          List<String> nuevosDrivers = driversStream
              .where((id) => !notifiedDrivers.contains(id))
              .toList();

          if (nuevosDrivers.isEmpty) {
            print("PORTERIA sin nuevos conductores");
            return;
          }

          print("🆕 PORTERIA nuevos conductores: ${nuevosDrivers.length}");

          /// 🔥 agregar sin borrar
          nearbyDrivers.addAll(nuevosDrivers);

          /// 🔥 BLOQUEAR
          _isSendingNotifications = true;

          try {
            await _attemptToSendNotificationPorteria(
              nearbyDrivers,
              notifiedDrivers.length,
            );
          } catch (e) {
            print("Error en envío porteria: $e");
          }

          /// 🔥 DESBLOQUEAR
          _isSendingNotifications = false;

        }, onError: (error) {
          print("Error en stream porteria: $error");
        });
  }

  Future<bool> hayConductoresEnRadio() async {

    final stream = _geofireProvider.getNearbyDrivers(
      fromLatlng.latitude,
      fromLatlng.longitude,
      radioDeBusqueda ?? 1,
    );

    final completer = Completer<bool>();

    late StreamSubscription sub;

    sub = stream.listen((List<DocumentSnapshot> docs) {

      sub.cancel();

      if (docs.isEmpty) {
        completer.complete(false);
      } else {
        completer.complete(true);
      }

    });

    return completer.future;
  }


  // Future<void> _attemptToSendNotification(List<String> driverIds, int index) async {
  //
  //   if (_tiempoAgotado()) {
  //     print("⛔ Tiempo global agotado (NORMAL), detener notificaciones");
  //     notifiedDrivers.clear();
  //     return;
  //   }
  //
  //   if (index >= driverIds.length) {
  //
  //     print("🏁 Fin de lista de conductores");
  //
  //     /// 🔥 marcar que ya intentamos todos los VIP
  //     if ((tipoServicioSolicitado ?? "").toLowerCase() == "vip" && !_permitirStandard) {
  //       yaIntentoTodosLosVIP = true;
  //       print("⚠️ Ya se intentaron todos los VIP");
  //     }
  //
  //     return;
  //   }
  //
  //   String driverId = driverIds[index];
  //
  //   if (notifiedDrivers.contains(driverId)) {
  //     return await _attemptToSendNotification(driverIds, index + 1);
  //   }
  //
  //   notifiedDrivers.add(driverId);
  //
  //   print("Enviando notificación al conductor $driverId");
  //
  //   try {
  //
  //     Driver? driver = await _driverProvider.getById(driverId);
  //
  //     print("🧍 tipoServicioSolicitado*******************: $tipoServicioSolicitado");
  //
  //     // 🔥 VALIDACIÓN VIP (YA SIN FIRESTORE)
  //     if ((tipoServicioSolicitado ?? "").toLowerCase() == "vip") {
  //
  //       final vehiculoData = vehiculosCache[driverId];
  //
  //       // 🔥 SI NO HAY VEHÍCULO EN CACHE → SALTAR
  //       if (vehiculoData == null) {
  //         print("❌ Vehículo no cargado en cache");
  //         return await _attemptToSendNotification(driverIds, index + 1);
  //       }
  //
  //       final soportaVIP = vehiculoData['soportaVIP'] ?? false;
  //
  //       // 🔥 BLOQUEO SOLO EN FASE VIP
  //       if (!_permitirStandard && !soportaVIP) {
  //         print("⛔ Conductor no VIP (fase 1)");
  //         return await _attemptToSendNotification(driverIds, index + 1);
  //       }
  //
  //       // 🔥 FALLBACK
  //       if (_permitirStandard) {
  //         print("⚠️ Fallback activo → permitiendo estándar");
  //       }
  //     }
  //
  //     // 🔥 ENVÍO NOTIFICACIÓN
  //     if (driver?.token != null && driver!.token.isNotEmpty) {
  //
  //       bool accepted = await sendNotification(driver.token);
  //
  //       if (accepted) {
  //         serviceAccepted = true;
  //
  //         _timeoutBusqueda?.cancel();
  //         _streamSubscription?.cancel();
  //
  //         notifiedDrivers.clear();
  //
  //         return;
  //       }
  //     }
  //
  //   } catch (e) {
  //     print("Error driver: $e");
  //   }
  //
  //   /// 🔥 continuar secuencia CONTROLADA
  //   return await _attemptToSendNotification(driverIds, index + 1);
  // } cambio para enviar e 2 conductores a la vez 26 abril de 2026



  Future<void> _attemptToSendNotification(List<String> driverIds, int index) async {

    // 🔥 STOP inmediato si ya aceptaron
    if (serviceAccepted) {
      print("🛑 Servicio ya aceptado, deteniendo envíos");
      return;
    }

    print("📊 Intentando drivers desde index: $index | total: ${driverIds.length}");

    if (_tiempoAgotado()) {
      print("⛔ Tiempo global agotado (NORMAL), detener notificaciones");
      notifiedDrivers.clear();
      return;
    }

    if (index >= driverIds.length) {

      print("🏁 Fin de lista de conductores");

      if ((tipoServicioSolicitado ?? "").toLowerCase() == "vip" && !_permitirStandard) {
        yaIntentoTodosLosVIP = true;
        print("⚠️ Ya se intentaron todos los VIP");
      }

      return;
    }

    // 🔥 ARMAR BATCH DE 2
    List<String> batch = [];

    for (int i = index; i < index + 2 && i < driverIds.length; i++) {
      if (!notifiedDrivers.contains(driverIds[i])) {
        batch.add(driverIds[i]);
        notifiedDrivers.add(driverIds[i]);
      }
    }

    if (batch.isEmpty) {
      return await _attemptToSendNotification(driverIds, index + 2);
    }

    print("🚀 Batch seleccionado: $batch");

    try {

      await Future.wait(
        batch.map((driverId) async {

          // 🔥 STOP dentro del batch
          if (serviceAccepted) return;

          try {

            print("📡 Enviando notificación a driver: $driverId");

            Driver? driver = await _driverProvider.getById(driverId);

            if (driver == null) {
              print("⚠️ Driver $driverId no encontrado");
              return;
            }

            // 🔥 VALIDACIÓN VIP
            if ((tipoServicioSolicitado ?? "").toLowerCase() == "vip") {

              final vehiculoData = vehiculosCache[driverId];

              if (vehiculoData == null) {
                print("❌ Vehículo no cargado en cache ($driverId)");
                return;
              }

              final soportaVIP = vehiculoData['soportaVIP'] ?? false;

              if (!_permitirStandard && !soportaVIP) {
                print("⛔ Conductor $driverId no es VIP");
                return;
              }

              if (_permitirStandard) {
                print("⚠️ Fallback activo → permitiendo estándar ($driverId)");
              }
            }

            // 🔥 VALIDAR TOKEN
            if (driver.token == null || driver.token.isEmpty) {
              print("⚠️ Driver $driverId sin token");
              return;
            }

            print("📤 Enviando push a token: ${driver.token.substring(0, 10)}...");

            bool accepted = await sendNotification(driver.token);

            if (accepted) {

              print("✅ Driver $driverId ACEPTÓ el servicio");

              serviceAccepted = true;

              _timeoutBusqueda?.cancel();
              _streamSubscription?.cancel();

              notifiedDrivers.clear();

              return;
            } else {
              print("⏱ Driver $driverId no respondió");
            }

          } catch (e) {
            print("❌ Error driver $driverId: $e");
          }

        }),
      );

    } catch (e) {
      print("❌ Error en batch: $e");
    }

    // 🔥 STOP si alguien aceptó
    if (serviceAccepted) {
      print("🛑 STOP GLOBAL: servicio aceptado");
      return;
    }

    print("➡️ Batch finalizado, pasando al siguiente...");

    // 🔥 SIGUIENTE BATCH
    return await _attemptToSendNotification(driverIds, index + 2);
  }

  void permitirStandardManual() async {

    _permitirStandard = true;

    print("🔁 Usuario acepta estándar");

    // 🔥 SOLO eliminar los que NO son VIP
    notifiedDrivers.removeWhere((driverId) {
      final vehiculoData = vehiculosCache[driverId];
      final soportaVIP = vehiculoData?['soportaVIP'] ?? false;

      // 👉 eliminar SOLO los que NO son VIP
      return !soportaVIP;
    });

    if (nearbyDrivers.isNotEmpty) {
      print("🔁 Reintentando manual con estándar");
      await _attemptToSendNotification(nearbyDrivers, 0);
    }
  }

  void playAudio(String audioPath) async {
    print('****************************Reproduciendo audio con objeto _audioPlayer: $_audioPlayer');
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.stop(); // Detener cualquier reproducción anterior.
      }
      await _audioPlayer.setAsset('asset:$audioPath'); // Establecer el audio a reproducir.
      await _audioPlayer.play(); // Reproducir el audio.
    } catch (e) {
      if (kDebugMode) {
        print('Error al reproducir el audio: $e');
      }
    }
  }



  void _checkDriverResponse() {
    Stream<DocumentSnapshot> stream = _travelInfoProvider.getByIdStream(_authProvider.getUser()!.uid);
    _streamStatusSuscription = stream.listen((DocumentSnapshot document) {
      if (document.exists && document.data() != null) {
        Map<String, dynamic> data = document.data() as Map<String, dynamic>;
        TravelInfo travelInfo = TravelInfo.fromJson(data);

        if (travelInfo.status == 'accepted') {
          serviceAccepted = true; // Detener el envío de notificaciones

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const TravelMapPage()),
                (route) => false,
          );
        }

        if (travelInfo.status == 'no_driver_found' && _tiempoAgotado()) {

          print("🚫 No se encontró conductor");

          if (context != null) {

            showDialog(
              context: context!,
              builder: (context) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      Image.asset(
                        'assets/metax_logo.png',
                        height: 70,
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "Sin taxis disponibles",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "No encontramos conductores para tu solicitud 🚕\n\nPuedes intentarlo nuevamente en unos segundos.",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Entendido"),
                      ),
                    ),
                  ],
                );
              },
            );

            deleteTravelInfo(); // 🔥 limpia el request
          }
        }
      }
    });
  }


  Future<void> createTravelInfo({
    required String tipoServicio,
    required int valorVipExtra,
    required int tarifaFinal,
    required String metodoPago,
    required String caracteristicaVehiculo,
  }) async {

    tipoServicioSolicitado = tipoServicio;
    final user = _authProvider.getUser();
    if (user == null) return;

    final travelInfo = TravelInfo(
      id: user.uid,
      status: 'created',
      idDriver: "",
      from: from,
      to: to,
      idTravelHistory: "",
      fromLat: fromLatlng.latitude,
      fromLng: fromLatlng.longitude,
      toLat: toLatlng.latitude,
      toLng: toLatlng.longitude,

      tarifa: tarifaFinal.toDouble(),
      tarifaDescuento: 0,
      tarifaInicial: tarifaFinal.toDouble(),

      distancia: distancia.toDouble(),
      tiempoViaje: tiempoEnMinutos,
      horaInicioViaje: null,
      horaSolicitudViaje: Timestamp.now(),
      horaFinalizacionViaje: null,
      apuntes: apuntesAlConductor ?? '',

      // 🔥 CLIENTE
      tipoServicio: tipoServicio,
      valorVipExtra: valorVipExtra,
      metodoPago: metodoPago,
      caracteristicaVehiculo: caracteristicaVehiculo,

      // 🔥 VEHÍCULO (vacío hasta que acepten)
      placa: '',
      marca: '',
      color: '',
      tipoVehiculo: '',
      tipoVehiculoServicio: '',

    );

    await _travelInfoProvider.create(travelInfo);
    _checkDriverResponse();
  }

  Future<void> getDriverInfo(String idDriver) async {
  }

  Future<bool> sendNotification(String token) async {
    final user = _authProvider.getUser();
    if (user == null) {
      return false;
    }

    final data = {
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',

      // 🔥 CLAVES NUEVAS
      'tipo': 'servicio',
      'tipoSolicitud': (tipoServicioSolicitado ?? '').toLowerCase() == 'porteria'
          ? 'porteria'
          : 'normal',

      // 🔥 TU DATA ORIGINAL
      'idClient': user.uid,
      'origin': from,
      'originLat': fromLatlng.latitude.toString(),
      'originLng': fromLatlng.longitude.toString(),
      'destination': to,
      'destinationLat': toLatlng.latitude.toString(),
      'destinationLng': toLatlng.longitude.toString(),
      'tarifa': totalInt.toString(),
      'apuntes_usuario': apuntesAlConductor,
    };
    print("🔥 ENVIANDO DATA: $data");

    try {
      await _pushNotificationsProvider.sendMessage(token, data);
      if (kDebugMode) {
        print('Notification sent successfully');
      }
      int segundosRestantes = _deadlineBusqueda!
          .difference(DateTime.now())
          .inSeconds;

      if (segundosRestantes <= 0) {
        print("⛔ Sin tiempo restante (NORMAL)");
        return false;
      }

      /// usar el menor entre 12 y el tiempo restante
      int tiempoEspera = segundosRestantes > 8 ? 8 : segundosRestantes;

      print("⏱️ Esperando $tiempoEspera segundos para respuesta del conductor (NORMAL)");

      await Future.delayed(Duration(seconds: tiempoEspera));
      return false;
    } catch (error) {
      if (kDebugMode) {
        print('Failed to send notification: $error');
      }
      return false;
    }
  }

  //PARA PORTERIA

  Future<bool> sendNotificationPorteria(String token) async {

    final doc = await FirebaseFirestore.instance
        .collection("TravelRequests")
        .doc(requestId)
        .get();

    final dataRequest = doc.data();

    final data = {
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'tipoSolicitud': 'porteria',

      'origin': dataRequest?["direccion"],

      'originLat': dataRequest?["lat"].toString(),
      'originLng': dataRequest?["lng"].toString(),

      'nombreConjunto': dataRequest?["nombreConjunto"] ?? '',
      'metodoPago': dataRequest?["metodoPago"] ?? '',
      'caracteristica': dataRequest?["caracteristica"] ?? '',
      'barrio': dataRequest?["barrio"] ?? "",
      'id': requestId ?? '',

      'mensaje': 'Servicio solicitado desde portería'
    };

    await _pushNotificationsProvider.sendMessage(token, data);

    int segundosRestantes = _deadlineBusqueda!
        .difference(DateTime.now())
        .inSeconds;

    if (segundosRestantes <= 0) {
      print("⛔ Sin tiempo restante (sendNotification)");
      return false;
    }

    /// usar el menor entre 20 y el tiempo restante
    int tiempoEspera = segundosRestantes > 14 ? 14 : segundosRestantes;

    print("⏱️ Esperando $tiempoEspera segundos para respuesta del conductor");

    await Future.delayed(Duration(seconds: tiempoEspera));

    return false;
  }

  Future<void> _attemptToSendNotificationPorteria(List<String> driverIds, int index) async {
    if (serviceAccepted) return;

    if (_tiempoAgotado()) {
      print("⛔ Tiempo global agotado (PORTERIA)");
      return;
    }

    if (requestId == null) return;

    /// 🔥 validar estado actual
    final requestDoc = await FirebaseFirestore.instance
        .collection("TravelRequests")
        .doc(requestId)
        .get();

    if (!requestDoc.exists) return;

    final status = requestDoc.data()?["status"] ?? "";

    if (status != "created") {
      print("⛔ STOP GLOBAL ($status)");
      return;
    }

    /// 🔥 fin de lista
    if (index >= driverIds.length || serviceAccepted) {

      print("🚫 No hay más conductores disponibles (PORTERIA)");

      if (!serviceAccepted && requestId != null) {
        final doc = await FirebaseFirestore.instance
            .collection("TravelRequests")
            .doc(requestId)
            .get();

        final status = doc.data()?["status"];

        if (status == "created") {
          await FirebaseFirestore.instance
              .collection("TravelRequests")
              .doc(requestId)
              .update({
            "status": "no_driver_found"
          });
        }
      }

      return;
    }

    String driverId = driverIds[index];

    /// 🔥 evitar duplicados
    if (notifiedDrivers.contains(driverId)) {
      return await _attemptToSendNotificationPorteria(driverIds, index + 1);
    }

    notifiedDrivers.add(driverId);

    print("📡 PORTERIA → Enviando a $driverId");

    try {

      Driver? driver = await _driverProvider.getById(driverId);

      if (driver?.token != null) {

        bool accepted = await sendNotificationPorteria(driver!.token);

        if (accepted) {

          serviceAccepted = true;

          _timeoutBusqueda?.cancel();
          _streamSubscriptionPorteria?.cancel();

          print("✅ Servicio aceptado PORTERIA");

          return;
        }

      } else {
        print("⚠️ Driver sin token");
      }

    } catch (e) {
      print("Error driver porteria: $e");
    }

    /// 🔥 continuar secuencia
    return await _attemptToSendNotificationPorteria(driverIds, index + 1);
  }

  //*nuevo para filtrar los conductores no activos antes de enviar notificacion//************************


  bool estaActivoRecientementeDesdeLocation(Map<String, dynamic> data) {
    try {
      final now = DateTime.now();

      // 🔥 OJO: está dentro de position
      final position = data['position'];
      if (position == null) return false;

      final updatedAt = position['updatedAt']?.toDate();
      if (updatedAt == null) return false;

      final minutos = now.difference(updatedAt).inMinutes;

      // 🔥 AQUÍ defines la regla
      return minutos <= 2;

    } catch (e) {
      print("⚠️ Error validando activity location: $e");
      return false;
    }
  }


}
