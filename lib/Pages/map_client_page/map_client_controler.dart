import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
import '../../helpers/conectivity_service.dart';
import '../../helpers/snackbar.dart';
import 'dart:math' as Math;


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
  //late StreamSubscription<Position> _positionStream; comentado prueba 1
  StreamSubscription<Position>? _positionStream;
  late BitmapDescriptor markerClient;
  late BitmapDescriptor markerDriver;
  late GeofireProvider _geofireProvider;
  late MyAuthProvider _authProvider;
  late ClientProvider _clientProvider;
  late StreamSubscription<DocumentSnapshot<Object?>> _clientInfoSuscription;
  late StreamSubscription<List<DocumentSnapshot>>? _driversSubscription;
  late PushNotificationsProvider _pushNotificationsProvider;

  // ClientMapController() {
  //   _initializePositionStream();
  // } comentado prueba 1
  ClientMapController();

  Client? client;
  String? from;
  LatLng? fromlatlng;
  String? to;
  LatLng? tolatlng;
  LatLng? currentLocation;

  final ConnectionService _connectionService = ConnectionService();
  bool isConnected = false; //**para validar el estado de conexion a internet
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;  // Suscripción para escuchar cambios en conectividad

  // Inicializar _positionStream
  void startPositionStream() {
    _positionStream = Geolocator.getPositionStream().listen((Position position) {
      _position = position;
    });
  }

  final Set<String> _visibleDriverIds = {};



  Future<void> init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;

    _geofireProvider = GeofireProvider();
    _authProvider = MyAuthProvider();
    _clientProvider = ClientProvider();
    _pushNotificationsProvider = PushNotificationsProvider();

    // markerClient = await createMarkerImageFromAssets('assets/ubicacion_client.png');
    // markerDriver = await createMarkerImageFromAssets('assets/marker_conductores.png'); comenatdo prueba 1

    // Carga marcadores en paralelo (más rápido)
    final markersFuture = Future.wait([
      createMarkerImageFromAssets('assets/ubicacion_client.png'),
      createMarkerImageFromAssets('assets/marker_taxi.png'),
    ]);

    //checkGPS(); prueba 1
    checkGPS();

    await checkConnectionAndShowSnackbar();

    final markersLoaded = await markersFuture;
    markerClient = markersLoaded[0];
    markerDriver = markersLoaded[1];
    await obtenerDatos();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      checkConnectionAndShowSnackbar();
      refresh();
    });
  }


  //helpers movimiento carro

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  double _distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  LatLng _moveTowards(LatLng current, LatLng target, double metersStep) {
    final d = _distanceMeters(current, target);
    if (d <= metersStep || d == 0) return target;

    final t = metersStep / d;
    return LatLng(
      _lerpDouble(current.latitude, target.latitude, t),
      _lerpDouble(current.longitude, target.longitude, t),
    );
  }

  double _lerpHeading(double a, double b, double t) {
    double diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    return (a + diff * t) % 360;
  }

  double _bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * (Math.pi / 180.0);
    final lon1 = a.longitude * (Math.pi / 180.0);
    final lat2 = b.latitude * (Math.pi / 180.0);
    final lon2 = b.longitude * (Math.pi / 180.0);

    final dLon = lon2 - lon1;

    final y = Math.sin(dLon) * Math.cos(lat2);
    final x = Math.cos(lat1) * Math.sin(lat2) -
        Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);

    var brng = Math.atan2(y, x) * (180.0 / Math.pi);
    brng = (brng + 360.0) % 360.0;
    return brng;
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
    Snackbar.showSnackbar(context,  'No se pudieron obtener los datos. Inténtalo de nuevo más tarde.');
  }

  Future<void> _obtenerDatosDeUbiucacion() async {
    // Obtener la posición actual y establecerla como posición inicial
    _position = await Geolocator.getCurrentPosition();
    if (_position != null) {
      initialPosition = CameraPosition(
        target: LatLng(_position!.latitude, _position!.longitude),
        zoom: 20.0,
      );
    }
    saveToken();
    getClientInfo();
    getNearbyDrivers();
  }

  // Método para verificar la conexión a Internet y mostrar el Snackbar si no hay conexión
  Future<void> checkConnectionAndShowSnackbar() async {
    await _connectionService.checkConnectionAndShowCard(context, () {
      // Callback para manejar la reconexión a Internet
      refresh();
    });
  }
  void _initializePositionStream() {
    // Inicializa tu _positionStream aquí
    _positionStream = Geolocator.getPositionStream().listen((Position position) {
      // Manejar la posición actualizada
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


  void getNearbyDrivers() {
    if (_position == null) return;

    final stream = _geofireProvider.getNearbyDrivers(
      _position!.latitude,
      _position!.longitude,
      1,
    );

    _driversSubscription?.cancel();
    _driversSubscription = stream.listen((List<DocumentSnapshot> documentList) {
      // ✅ 1) Mantener/actualizar marcador del cliente
      addMarker(
        'client',
        _position!.latitude,
        _position!.longitude,
        'Tu posición',
        '',
        markerClient,
      );

      // ✅ 2) IDs que vienen en este snapshot
      final idsEnStream = <String>{};

      for (final d in documentList) {
        idsEnStream.add(d.id);

        final positionData = d.get('position') as Map<String, dynamic>?;
        if (positionData == null) continue;

        final geoPoint = positionData['geopoint'] as GeoPoint?;
        if (geoPoint == null) continue;

        final headingRaw = positionData['heading'];
        final heading = (headingRaw is num) ? headingRaw.toDouble() : 0.0;

        // ✅ Actualiza marker del driver (sin titileo)
        addMarkerDriver(
          d.id,
          geoPoint.latitude,
          geoPoint.longitude,
          'Conductor disponible',
          '',
          markerDriver,
          heading: heading,
        );
      }

      // ✅ 3) Borrar del mapa los que ya NO están en el stream
      final idsAnteriores = Set<String>.from(_visibleDriverIds);
      for (final id in idsAnteriores) {
        if (!idsEnStream.contains(id)) {
          markers.remove(MarkerId(id));
          _visibleDriverIds.remove(id);
        }
      }

      // ✅ 4) Actualiza el set de visibles
      _visibleDriverIds
        ..clear()
        ..addAll(idsEnStream);

      refresh();
    });
  }



  void dispose(){
    _positionStream?.cancel();
    _clientInfoSuscription.cancel();
    _driversSubscription?.cancel();
    _connectivitySubscription?.cancel();
  }

  void onMapCreated(GoogleMapController controller){
    controller.setMapStyle(utilsMap.mapStyle);
    _mapController.complete(controller);
  }

  void updateLocation() async {
    try {
      await _determinePosition();
      //_position = (await Geolocator.getLastKnownPosition())!; comentado prueba 1
      _position = await Geolocator.getLastKnownPosition();
      _position ??= await Geolocator.getCurrentPosition();

      if (_position != null) {
        centerPosition();

        addMarker(
            'client',
            _position!.latitude,
            _position!.longitude,
            "Tu posición", "",
            markerClient
        );

        //getNearbyDrivers(); comentado prueba 1
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

  void opendrawer(){
    key.currentState?.openDrawer();
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
  void goToEliminarCuenta(){
    Navigator.pushNamed(context, "eliminar_cuenta");
  }

  void requestDriver() {
    if (fromlatlng != null && tolatlng != null) {
      // Verificar si las coordenadas de origen y destino son iguales
      if (from == to) {
        // Mostrar un Snackbar informando que las coordenadas son iguales
        if (key.currentState != null) {
          Snackbar.showSnackbar(context, 'La posición de origen es la misma que el destino. Verifica el destino e intentalo nuevamente');
        }
      } else {
        // Si las coordenadas no son iguales, navega a la página de viaje
        Navigator.pushNamed(context, "travel_info_page", arguments: {
          'from': from,
          'to': to,
          'fromlatlng': fromlatlng,
          'tolatlng': tolatlng,
        });
      }
    } else {
      // Si no se han seleccionado las coordenadas, mostrar un Snackbar
      if (key.currentState != null) {
        Snackbar.showSnackbar(context,  'Debes seleccionar el lugar de origen y destino');
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
      BitmapDescriptor iconMarker, {
        double heading = 0.0,
      }) {
    final id = MarkerId(markerId);

    markers[id] = Marker(
      markerId: id,
      icon: iconMarker,
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(title: title, snippet: content),
      draggable: false,
      zIndex: 2,
      flat: true,
      rotation: heading,
      anchor: const Offset(0.5, 0.5),
    );
  }

}

