import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ModalBottomSheetRoute;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location;
import '../../../../providers/auth_provider.dart';
import '../../../../providers/client_provider.dart';
import '../../../../providers/geofire_provider.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../providers/push_notifications_provider.dart';
import 'package:apptaxis/models/client.dart';
import 'package:apptaxis/utils/utilsMap.dart';
import '../../helpers/snackbar.dart';
import '../../providers/price_provider.dart';
import '../../service/connection_service_singleton.dart';
import 'dart:io';
import 'dart:ui' as ui;

class ClientMapController {
  late BuildContext context;
  late Function refresh;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _mapController = Completer();
  Future<GoogleMapController> get mapController => _mapController.future;

  CameraPosition initialPosition = const CameraPosition(
    target: LatLng(4.8470616, -74.0743461),
    zoom: 20.0,

  );

  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};

  Position? _position;
  late StreamSubscription<Position> _positionStream;
  late BitmapDescriptor markerClient;
  late BitmapDescriptor markerDriver;
  late GeofireProvider _geofireProvider;
  late MyAuthProvider _authProvider;
  late ClientProvider _clientProvider;
  late StreamSubscription<DocumentSnapshot<Object?>> _clientInfoSuscription;
  StreamSubscription<List<DocumentSnapshot>>? _driversSubscription;
  late PushNotificationsProvider _pushNotificationsProvider;

  ClientMapController() {
    _initializePositionStream();
  }

  Client? client;
  String? from;
  LatLng? fromlatlng;
  bool usandoUbicacionManual = false;
  String? to;
  LatLng? tolatlng;
  LatLng? currentLocation;
  bool isConnected = false; //**para validar el estado de conexion a internet

  bool _pedirCedula = false;
  int _cedulaDespuesDeViajes = 1;



  // Inicializar _positionStream
  void startPositionStream() {
    _positionStream = Geolocator.getPositionStream().listen((Position position) {
      _position = position;
    });
  }

  Future<void> init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    _geofireProvider = GeofireProvider();
    _authProvider = MyAuthProvider();
    _clientProvider = ClientProvider();

    // =========================================================================
    // 🔥 AJUSTE DINÁMICO DE MARCADORES PARA ESTA PANTALLA
    // =========================================================================
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Valores base finos y pequeños
    double baseDriver = 11.0;  // Tamaño para los taxis en el radar
    double baseClient = 13.0;  // Tamaño para tu pin de ubicación

    if (Platform.isIOS) {
      baseDriver = 11.0;
      baseClient = 13.0;
    } else if (Platform.isAndroid) {
      baseDriver = 11.0;
      baseClient = 13.0;
    }

    int finalWidthDriver = (baseDriver * pixelRatio).round();
    int finalWidthClient = (baseClient * pixelRatio).round();

    // Asignar las imágenes con el tamaño en píxeles reales calculados
    markerDriver = await createMarkerImageFromAssets('assets/marker_taxi.png', finalWidthDriver);
    markerClient = await createMarkerImageFromAssets('assets/ubicacion_client.png', finalWidthClient);
    // =========================================================================

    final config = await _clientProvider.getConfigCedula();
    _pedirCedula = config['cedula'] == true;
    _cedulaDespuesDeViajes = (config['cedula_despues_de_viajes'] as int?) ?? 1;

    _pushNotificationsProvider = PushNotificationsProvider();

    // Se eliminaron las dos líneas repetidas de abajo que sobreescribían el tamaño

    checkGPS();
    await obtenerDatos();
  }

  Future<void> obtenerDatos() async {
    int reintentos = 0;
    const int maxReintentos = 3;
    const Duration tiempoReintento = Duration(seconds: 2);

    while (reintentos < maxReintentos) {
      try {
        // Obtener datos aquí
        await _obtenerDatosDeUbiucacion();
        return;
      } catch (e) {
        reintentos++;
        await Future.delayed(tiempoReintento);
      }
    }

    // Mostrar mensaje de error si no se pudieron obtener los datos
    mostrarMensajeError();
  }



  void mostrarMensajeError() {
    Snackbar.showSnackbar(context, 'No se pudieron obtener los datos. Inténtalo de nuevo más tarde.');
  }

  Future<void> _obtenerDatosDeUbiucacion() async {
    // Obtener la posición actual y establecerla como posición inicial
    _position = await Geolocator.getCurrentPosition();
    if (_position != null) {
      currentLocation = LatLng(_position!.latitude, _position!.longitude);
      initialPosition = CameraPosition(
        target: LatLng(_position!.latitude, _position!.longitude),
        zoom: 16.0,
      );
    }
    saveToken();
    getClientInfo();
    getNearbyDrivers();
  }

  Future<void> checkConnectionAndShowSnackbar() async {
    await connectionService.checkConnectionAndShowCard(context, () {
      refresh();
    });
  }

  void _initializePositionStream() {

    _positionStream =

        Geolocator
            .getPositionStream()

            .listen((Position position) {

          /// 🔥 SI EL USUARIO
          /// ESTÁ USANDO
          /// UBICACIÓN MANUAL
          /// NO SOBREESCRIBIR

          if (usandoUbicacionManual) {
            return;
          }

          _position = position;
        });
  }


  Future<Null> setLocationdraggableInfo() async {
    // 🔥 SI EL USUARIO YA SELECCIONÓ UN DESTINO CON PLACES, NO PERMITIR QUE EL ONCAMERAIDLE LO PISE
    if (tolatlng != null && to != null && to!.isNotEmpty && !usandoUbicacionManual) {
      return;
    }

    double lat = initialPosition.target.latitude;
    double lng = initialPosition.target.longitude;
    List<Placemark> address = await placemarkFromCoordinates(lat, lng);

    if (address.isNotEmpty) {
      String? direction = address[0].thoroughfare;
      String? street = address[0].subThoroughfare;
      String? city = address[0].locality;
      String? department = address[0].administrativeArea;

      to = '$direction #$street, $city, $department';
      tolatlng = LatLng(lat, lng);
      refresh();
    }
  }

  void saveToken() {
    final user = _authProvider.getUser();
    if (user != null) {
      _pushNotificationsProvider.saveToken(user.uid);
    }
  }

  Future<void> setLocationdraggableInfoOrigen({
    bool useCameraPosition = false,
  }) async {
    // 🔥 SI YA SE USÓ AUTOCOMPLETE DE PLACES PARA EL ORIGEN Y NO SE ESTÁ EDITANDO MANUALMENTE EN EL MAPA, RESPETAR EL NOMBRE
    if (fromlatlng != null && from != null && from!.isNotEmpty && usandoUbicacionManual && !useCameraPosition) {
      return;
    }

    double lat;
    double lng;

    /// 🔥 USAR CENTRO DEL MAPA
    if (useCameraPosition) {
      lat = initialPosition.target.latitude;
      lng = initialPosition.target.longitude;
    }
    /// 🔥 USAR GPS REAL
    else {
      /// 🔥 SI HAY UBICACIÓN MANUAL
      if (usandoUbicacionManual && fromlatlng != null) {
        lat = fromlatlng!.latitude;
        lng = fromlatlng!.longitude;
      }
      /// 🔥 GPS NORMAL
      else {
        if (_position == null) {
          return;
        }
        lat = _position!.latitude;
        lng = _position!.longitude;
      }
    }

    List<Placemark> address = await placemarkFromCoordinates(lat, lng);

    if (address.isNotEmpty) {
      String? placeName = address[0].name;
      String? direction = address[0].thoroughfare;
      String? street = address[0].subThoroughfare;
      String? city = address[0].locality;
      String? department = address[0].administrativeArea;

      from = '$direction #$street, $city, $department';
      fromlatlng = LatLng(lat, lng);
      refresh();
    }
  }

  void getClientInfo() {
    final user = _authProvider.getUser();
    if (user != null) {
      Stream<DocumentSnapshot> clientStream = _clientProvider.getByIdStream(user.uid);
      _clientInfoSuscription = clientStream.listen((DocumentSnapshot document) {
        if (document.data() != null) {
          client = Client.fromJson(document.data() as Map<String, dynamic>);
          //refresh();
        }
      });
    }
  }


  void getNearbyDrivers() async {
    if (_position == null) return;

    try {
      double radio = 1;
      try {
        final price = await PricesProvider().getAll();
        radio = price.theRadioDeBusqueda;
      } catch (e) {
        if (kDebugMode) print("⚠️ Error radio dinámico, usando 1km: $e");
      }

      _driversSubscription?.cancel();

      // Calculamos el tiempo límite (hace 10 minutos)
      final limiteTiempo = DateTime.now().subtract(const Duration(minutes: 10));

      Stream<List<DocumentSnapshot>> stream = _geofireProvider.getNearbyDrivers(
        _position!.latitude,
        _position!.longitude,
        radio,
      );

      _driversSubscription = stream.listen((List<DocumentSnapshot> documentList) {

        // 1. Limpiar marcadores antiguos
        markers.removeWhere((key, marker) => key.value != 'client');

        // 2. Mantener marcador del cliente
        addMarker(
          'client',
          _position!.latitude,
          _position!.longitude,
          'Tu posición',
          "",
          markerClient,
        );

        for (DocumentSnapshot d in documentList) {
          try {
            Map<String, dynamic> data = d.data() as Map<String, dynamic>;
            Map<String, dynamic> positionData = d.get('position');

            // 🔥 OPTIMIZACIÓN: Validación de actividad (Filtro Anti-Zombies)
            Timestamp? updatedAt = positionData['updatedAt'] as Timestamp?;
            if (updatedAt == null || updatedAt.toDate().isBefore(limiteTiempo)) {
              // Si el driver está desactualizado, lo ignoramos y no le creamos marcador
              continue;
            }

            if (positionData.containsKey('geopoint')) {
              GeoPoint geoPoint = positionData['geopoint'];

              double distanceInKm = Geolocator.distanceBetween(
                _position!.latitude,
                _position!.longitude,
                geoPoint.latitude,
                geoPoint.longitude,
              ) / 1000;

              if (distanceInKm <= radio) {
                double rotation = double.tryParse(data['heading']?.toString() ?? '0') ?? 0;

                addMarkerDriver(
                  d.id,
                  geoPoint.latitude,
                  geoPoint.longitude,
                  'Conductor disponible',
                  "",
                  markerDriver,
                  rotation: rotation,
                );
              }
            }
          } catch (e) {
            if (kDebugMode) print("⚠️ Error procesando driver ${d.id}: $e");
          }
        }

        if (context.mounted) {
          refresh();
        }
      });

    } catch (e) {
      if (kDebugMode) print("❌ Error general en getNearbyDrivers: $e");
    }
  }

  void dispose(){
    _positionStream.cancel();
    _clientInfoSuscription.cancel();
    _driversSubscription?.cancel();
    //_connectivitySubscription?.cancel();
  }

  void onMapCreated(GoogleMapController controller){
    controller.setMapStyle(utilsMap.mapStyle);
    _mapController.complete(controller);
  }

  void updateLocation() async {
  try {

    _position = await _determinePosition();

    if (_position != null) {

      currentLocation = LatLng(
        _position!.latitude,
        _position!.longitude,
      );

      centerPosition();

      addMarker(
        'client',
        _position!.latitude,
        _position!.longitude,
        "Tu posición",
        "",
        markerClient,
      );

      getNearbyDrivers();
    }

  } catch (error) {
    print('Error en la localizacion: $error');
  }
}

  void centerPosition() {
    if (_position != null) {
      animateCameraToPosition(_position!.latitude, _position!.longitude);
    }
  }

  void actualizarPosicionManual() {

    if (fromlatlng == null) {
      return;
    }

    _position = Position(

      longitude:
      fromlatlng!.longitude,

      latitude:
      fromlatlng!.latitude,

      timestamp:
      DateTime.now(),

      accuracy: 1,

      altitude: 0,

      altitudeAccuracy: 1,

      heading: 0,

      headingAccuracy: 1,

      speed: 0,

      speedAccuracy: 1,
    );

    /// 🔥 ELIMINAR MARKER VIEJO
    markers.remove(
      const MarkerId('client'),
    );

    /// 🔥 CREAR NUEVO MARKER
    addMarker(

      'client',

      fromlatlng!.latitude,

      fromlatlng!.longitude,

      'Tu posición',

      '',

      markerClient,
    );

    usandoUbicacionManual = true;

    refresh();
  }

  void checkGPS() async{
    bool islocationEnabled = await Geolocator.isLocationServiceEnabled();
    if(islocationEnabled){
      updateLocation();
    }
    else{
      bool locationGPS = await location.Location().requestService();
      if(locationGPS){
        updateLocation();
      }
    }
  }


  void goToHistorialViajes(){
    Navigator.pushNamed(context, "historial_viajes");
  }
  void goToPoliticasDePrivacidad(){
    Navigator.pushNamed(context, "politicas_de_privacidad");
  }
  void goToContactanos(){
    Navigator.pushNamed(context, "contactanos");
  }
  void goToCompartirAplicacion(){
    Navigator.pushNamed(context, "compartir_aplicacion");
  }
  void goToProfile(){
    Navigator.pushNamed(context, "profile");
  }
  void goToEliminarCuenta() {
    Navigator.pushNamed(context, "eliminar_cuenta");
  }


  void requestDriver() async {
    await connectionService.checkConnectionAndShowCard(context, () => refresh());

    final user = _authProvider.getUser();
    if (user == null) return;

    final c = await _clientProvider.getById(user.uid);
    if (c == null) {
      if (context.mounted) {
        Snackbar.showSnackbar(context, 'No pudimos validar tu cuenta. Intenta de nuevo.');
      }
      return;
    }

    final int viajes = c.viajes;

    // ===============================
    // 🔒 VALIDACIÓN CÉDULA
    // ===============================
    if (_pedirCedula && viajes >= _cedulaDespuesDeViajes) {

      final String estadoFront = c.cedulaFrontalEstado.toLowerCase();
      final String estadoBack  = c.cedulaReversoEstado.toLowerCase();

      final bool frontExiste = c.cedulaFrontalUrl.isNotEmpty;
      final bool backExiste  = c.cedulaReversoUrl.isNotEmpty;

      // ❌ Si no ha subido fotos
      if (!frontExiste || !backExiste) {
        if (context.mounted) {
          Snackbar.showSnackbar(context, 'Para continuar debes subir tu cédula (frontal y reverso).');
          Navigator.pushNamed(context, 'upload_cedula');
        }
        return;
      }

      // ❌ Si fueron rechazadas
      final bool frontRechazada = estadoFront == 'rechazada';
      final bool backRechazada  = estadoBack == 'rechazada';

      if (frontRechazada || backRechazada) {
        if (context.mounted) {

          final String tipoCedula =
          frontRechazada && backRechazada
              ? 'ambas'
              : frontRechazada
              ? 'frontal'
              : 'reverso';

          final String mensaje =
          tipoCedula == 'ambas'
              ? 'Necesitamos que repitas las fotos de tu cédula (por ambas caras).'
              : tipoCedula == 'frontal'
              ? 'Necesitamos que repitas la foto FRONTAL de tu cédula.'
              : 'Necesitamos que repitas la foto REVERSO de tu cédula.';

          Snackbar.showSnackbar(
            context,
            '$mensaje Asegúrate de que se vea completa, sin reflejos y con buena luz.',
          );

          Navigator.pushNamed(
            context,
            'upload_cedula',
            arguments: {'tipo': tipoCedula},
          );
        }
        return;
      }

      // ❌ Si aún no están aprobadas
      if (estadoFront != 'aprobada' || estadoBack != 'aprobada') {
        if (context.mounted) {
          Snackbar.showSnackbar(
            context,
            'Estamos validando tu cédula. Intenta nuevamente en unos minutos.',
          );
        }
        return;
      }
    }

    // ===============================
    // 🔒 VALIDACIÓN FOTO PERFIL
    // ===============================
    final String estadoFoto = c.fotoPerfilEstado.toLowerCase();
    final bool fotoExiste = c.fotoPerfilUrl.isNotEmpty;

    if (!fotoExiste) {
      if (context.mounted) {
        Snackbar.showSnackbar(context, 'Debes tomar tu foto de perfil.');
        Navigator.pushNamed(context, 'take_foto_perfil');
      }
      return;
    }

    if (estadoFoto == 'rechazada') {
      if (context.mounted) {
        Snackbar.showSnackbar(context, 'Tu foto fue rechazada. Por favor sube una nueva.');
        Navigator.pushNamed(context, 'take_foto_perfil');
      }
      return;
    }

    // ===============================
    // 🚗 SOLICITAR VIAJE
    // ===============================
    if (fromlatlng != null && tolatlng != null) {
      if (from == to) {
        if (context.mounted) {
          Snackbar.showSnackbar(
            context,
            'El origen y destino no pueden ser iguales.',
          );
        }
      } else {
        if (context.mounted) {
          Map<String, dynamic>? promocion;

          try {

            final snapshot = await FirebaseFirestore.instance
                .collection('Promociones')
                .where('activo', isEqualTo: true)
                .limit(1)
                .get();

            if (snapshot.docs.isNotEmpty) {

              final doc = snapshot.docs.first;

              if (doc['tipo'] == 'primer_viaje'
                  && c.viajes == 0) {

                promocion = {
                  'id': doc.id,
                  ...doc.data(),
                };
              }
            }

          } catch(e) {
            print("❌ Error promo: $e");
          }
          if(context.mounted){
            Navigator.pushNamed(
              context,
              "travel_info_page",

              arguments: {

                'from': from,

                'to': to,

                'fromlatlng': fromlatlng,

                'tolatlng': tolatlng,

                'navKey':
                DateTime.now()
                    .microsecondsSinceEpoch
                    .toString(),

                'promocion_aplicada':
                promocion,
              },
            );
          }

        }
      }
    } else {
      if (context.mounted) {
        Snackbar.showSnackbar(context, 'Debes seleccionar origen y destino');
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    print("📍 Solicitando ubicación...");

    return await Geolocator.getCurrentPosition();
  }

  Future<void> animateCameraToPosition(double latitude, double longitude) async {
    GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        bearing: 0,
        target: LatLng(latitude, longitude),
        zoom: 16,
      ),
    ));
  }

  Future<BitmapDescriptor> createMarkerImageFromAssets(String path, int width) async {
    // 1. Cargar el archivo desde los assets a la memoria del teléfono
    ByteData data = await rootBundle.load(path);

    // 2. Decodificar la imagen usando el alias 'ui.' para evitar conflictos
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();

    // 3. Convertir la imagen procesada de nuevo a formato PNG usable por Google Maps
    ByteData? markerBuffer = await fi.image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(markerBuffer!.buffer.asUint8List());
  }


  void addMarker(
      String markerId,
      double lat,
      double lng,
      String title,
      String content,
      BitmapDescriptor iconMarker
      ) {
    MarkerId id = MarkerId(markerId);
    Marker marker = Marker(
      markerId: id,
      icon: iconMarker,
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(title: title, snippet: content),
      draggable: false,
      zIndex: 2,
      flat: true,
      anchor: const Offset(0.5, 0.5),
      // rotation: _position?.heading ?? 0,
    );

    markers[id] = marker;
  }
  void addMarkerDriver(

      String markerId,

      double lat,

      double lng,

      String title,

      String content,

      BitmapDescriptor iconMarker, {

        double rotation = 0,
      }) {

    MarkerId id = MarkerId(markerId);

    Marker marker = Marker(

      markerId: id,

      icon: iconMarker,

      position: LatLng(lat, lng),

      infoWindow: InfoWindow(
        title: title,
        snippet: content,
      ),

      draggable: false,

      zIndex: 2,

      flat: true,

      anchor: const Offset(0.5, 0.5),

      rotation: rotation,
    );

    markers[id] = marker;
  }

  //***nuevo para filtrar marcadores de vehiculos que no estan activos // ****************

  bool estaActivoRecientemente(Map<String, dynamic> data) {
    try {

      final now = DateTime.now();

      final position = data['position'];

      if (position == null) return false;

      final updatedAt = position['updatedAt']?.toDate();

      if (updatedAt == null) return false;

      final minutos = now.difference(updatedAt).inMinutes;

      return minutos <= 720;

    } catch (e) {

      print("⚠️ Error validando actividad: $e");

      return false;
    }
  }
}

