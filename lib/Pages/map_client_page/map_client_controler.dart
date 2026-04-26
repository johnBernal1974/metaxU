import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ModalBottomSheetRoute;
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

class ClientMapController {
  late BuildContext context;
  late Function refresh;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _mapController = Completer();

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

    final config = await _clientProvider.getConfigCedula();
    _pedirCedula = config['cedula'] == true;
    _cedulaDespuesDeViajes = (config['cedula_despues_de_viajes'] as int?) ?? 1;


    _pushNotificationsProvider = PushNotificationsProvider();

    markerClient = await createMarkerImageFromAssets('assets/ubicacion_client.png');
    markerDriver = await createMarkerImageFromAssets('assets/marker_conductores.png');

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
        zoom: 20.0,
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
    _positionStream = Geolocator.getPositionStream().listen((Position position) {
      _position = position; // ✅ IMPORTANTE
    });
  }


  Future<Null> setLocationdraggableInfo() async {
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

  Future<Null> setLocationdraggableInfoOrigen() async {
    if (_position != null) {
      double lat = _position!.latitude;
      double lng = _position!.longitude;
      List<Placemark> address = await placemarkFromCoordinates(lat, lng);

      if (address.isNotEmpty) {
        String? direction = address[0].thoroughfare;
        String? street = address[0].subThoroughfare;
        String? city = address[0].locality;
        String? department = address[0].administrativeArea;
        from = '$direction #$street, $city, $department';
        fromlatlng = LatLng(lat, lng);
        refresh();
      }
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
      // 🔥 Obtener radio dinámico desde Firestore
      double radio = 1;

      try {
        final price = await PricesProvider().getAll();
        radio = price.theRadioDeBusqueda;
      } catch (e) {
        if (kDebugMode) {
          print("⚠️ Error obteniendo radio dinámico, usando 1km por defecto: $e");
        }
      }

      if (kDebugMode) {
        print("📡 Buscando conductores en un radio de: $radio km");
      }

      // 🔥 Cancelar suscripción anterior (IMPORTANTE)
      _driversSubscription?.cancel();

      Stream<List<DocumentSnapshot>> stream =
      _geofireProvider.getNearbyDrivers(
        _position!.latitude,
        _position!.longitude,
        radio,
      );

      _driversSubscription = stream.listen((List<DocumentSnapshot> documentList) {

        // 🔥 Limpiar SOLO markers de conductores
        markers.removeWhere((key, marker) => key.value != 'client');

        // 🔥 Mantener marcador del cliente
        addMarker(
          'client',
          _position!.latitude,
          _position!.longitude,
          'Tu posición',
          "",
          markerClient,
        );

        // 🔥 Agregar conductores
        // for (DocumentSnapshot d in documentList) {
        //   try {
        //     Map<String, dynamic> positionData = d.get('position');
        //
        //     if (positionData.containsKey('geopoint')) {
        //       GeoPoint geoPoint = positionData['geopoint'];
        //
        //       double distanceInMeters = Geolocator.distanceBetween(
        //         _position!.latitude,
        //         _position!.longitude,
        //         geoPoint.latitude,
        //         geoPoint.longitude,
        //       );
        //
        //       double distanceInKm = distanceInMeters / 1000;
        //       if (kDebugMode) {
        //         print("🚗 Driver ${d.id} a ${distanceInKm.toStringAsFixed(2)} km");
        //       }
        //
        //       // 🔥 FILTRO REAL POR RADIO
        //       if (distanceInKm <= radio) {
        //         addMarkerDriver(
        //           d.id,
        //           geoPoint.latitude,
        //           geoPoint.longitude,
        //           'Conductor disponible',
        //           "",
        //           markerDriver,
        //         );
        //       }
        //
        //     }
        //   } catch (e) {
        //     if (kDebugMode) {
        //       print("⚠️ Error leyendo posición de driver ${d.id}: $e");
        //     }
        //   }
        // } para filtra los marcadores de vehiculos inactivos 26 abril 2026

        for (DocumentSnapshot d in documentList) {
          try {
            Map<String, dynamic> data = d.data() as Map<String, dynamic>;

            /// 🔥 NUEVO FILTRO
            if (!estaActivoRecientemente(data)) {
              print("⛔ Driver ${d.id} sin movimiento, NO se muestra en mapa");
              continue;
            }

            Map<String, dynamic> positionData = d.get('position');

            if (positionData.containsKey('geopoint')) {
              GeoPoint geoPoint = positionData['geopoint'];

              double distanceInMeters = Geolocator.distanceBetween(
                _position!.latitude,
                _position!.longitude,
                geoPoint.latitude,
                geoPoint.longitude,
              );

              double distanceInKm = distanceInMeters / 1000;

              if (distanceInKm <= radio) {
                addMarkerDriver(
                  d.id,
                  geoPoint.latitude,
                  geoPoint.longitude,
                  'Conductor disponible',
                  "",
                  markerDriver,
                );
              }
            }

          } catch (e) {
            print("⚠️ Error leyendo driver ${d.id}: $e");
          }
        }

        // 🔥 Refrescar mapa
        refresh();
      });

    } catch (e) {
      if (kDebugMode) {
        print("❌ Error general en getNearbyDrivers: $e");
      }
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
      await _determinePosition();
      _position = (await Geolocator.getLastKnownPosition())!;
      if (_position != null) {
        currentLocation = LatLng(_position!.latitude, _position!.longitude);
        centerPosition();

        addMarker(
            'client',
            _position!.latitude,
            _position!.longitude,
            "Tu posición", "",
            markerClient
        );

        getNearbyDrivers();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error en la localizacion: $error');
      }
    }
  }

  void centerPosition() {
    if (_position != null) {
      animateCameraToPosition(_position!.latitude, _position!.longitude);
    }
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
          Navigator.pushNamed(context, "travel_info_page", arguments: {
            'from': from,
            'to': to,
            'fromlatlng': fromlatlng,
            'tolatlng': tolatlng,
            'navKey': DateTime.now().microsecondsSinceEpoch.toString(),
          });
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

  Future<BitmapDescriptor> createMarkerImageFromAssets(String path) async {
    ImageConfiguration configuration = const ImageConfiguration();
    BitmapDescriptor bitmapDescriptor=
    await BitmapDescriptor.fromAssetImage(configuration, path);
    return bitmapDescriptor;
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
      anchor: const Offset(0.5, 1.0),
      // rotation: _position?.heading ?? 0,
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

      return minutos <= 2; // 🔥 regla

    } catch (e) {
      print("⚠️ Error validando actividad: $e");
      return false;
    }
  }
}

