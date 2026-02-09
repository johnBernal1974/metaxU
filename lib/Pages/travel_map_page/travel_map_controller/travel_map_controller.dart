
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:location/location.dart' as location;
import '../../../../providers/auth_provider.dart';
import '../../../../providers/client_provider.dart';
import '../../../../providers/driver_provider.dart';
import '../../../../providers/geofire_provider.dart';
import '../../../../providers/travel_info_provider.dart';
import '../../../helpers/bottom_sheet_driver_info.dart';
import '../../../helpers/conectivity_service.dart';
import '../../../helpers/snackbar.dart';
import '../../../models/driver.dart';
import '../../../models/travel_info.dart';
import 'package:apptaxis/models/client.dart';
import 'package:apptaxis/utils/utilsMap.dart';
import 'package:cloud_functions/cloud_functions.dart';



class TravelMapController{
  late BuildContext context;
  late Function refresh;
  bool isMoto = false;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _mapController = Completer();
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  CameraPosition initialPosition = const CameraPosition(
    target: LatLng(4.3445324, -74.3639381),
    zoom: 12.0,
  );
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  late BitmapDescriptor markerDriver;
  late GeofireProvider _geofireProvider;
  late MyAuthProvider _authProvider;
  late DriverProvider _driverProvider;
  late ClientProvider _clientProvider;
  bool isConected = true;
  //late StreamSubscription<DocumentSnapshot<Object?>> _statusSuscription;
  //late StreamSubscription<DocumentSnapshot<Object?>> _driverInfoSuscription;
  StreamSubscription<DocumentSnapshot<Object?>>? _streamLocationController;
  StreamSubscription<DocumentSnapshot<Object?>>? _streamTravelController;



  //late StreamSubscription<DocumentSnapshot<Object?>> _streamStatusController;
  late TravelInfoProvider _travelInfoProvider;
  late BitmapDescriptor fromMarker;
  late BitmapDescriptor toMarker;
  Position? _position;
  Driver? driver;
  Client? client;
  LatLng? _driverLatlng;
  TravelInfo? travelInfo;
  bool isRouteready = false;
  String currentStatus = '';
  bool isPickUpTravel = false;
  bool isStartTravel = false;
  bool isFinishtTravel = false;
  bool soundIsaceptado = false;
  Set<Polyline> polylines ={};
  List<LatLng> points = List.from([]);
  //int seconds = 0;
  //double mts = 0;
  //double kms = 0;
  LatLng? _from;
  LatLng? _to;
  LatLng? get from => _from;
  LatLng? get to => _to;
  //final StreamController<double> timeRemainingController = StreamController<double>.broadcast();
  //String? status = '';
  final ConnectionService connectionService = ConnectionService();
  //bool isConnected = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  //sounds
  late AudioPlayer _playerTaxiHaLlegado;
  bool _audioTaxiLlegadoYaReproducido = false;

  late AudioPlayer _playerConductorHaCancelado;
  bool _audioConductorHaCanceladoYaReproducido = false;

  //evitar traergetdriverinfo dos veces
  bool _didLoadTravel = false;

  //para calificacion
  double? ratingAvg;
  int ratingCount = 0;



  Future? init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    _geofireProvider = GeofireProvider();
    _authProvider = MyAuthProvider();
    _driverProvider = DriverProvider();
    _clientProvider = ClientProvider();
    _travelInfoProvider = TravelInfoProvider();
    markerDriver = await createMarkerImageFromAssets('assets/marker_taxi.png');
    fromMarker = await createMarkerImageFromAssets('assets/ubicacion_client.png');
    toMarker = await createMarkerImageFromAssets('assets/marker_destino.png');
    checkGPS();
    await checkConnectionAndShowSnackbar();
    // _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
    //   checkConnectionAndShowSnackbar();
    //   refresh();
    // }); 8 feb 2026

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((_) async {
          await checkConnectionAndShowSnackbar();
          if (context.mounted) refresh();
        });


    //_getTravelInfo();
    // obtenerStatus();
    _actualizarIsTravelingTrue();
    _position = await Geolocator.getCurrentPosition();
    if (_position != null) {
      initialPosition = CameraPosition(
        target: LatLng(_position!.latitude, _position!.longitude),
        zoom: 20.0,
      );
    }
    _playerTaxiHaLlegado = AudioPlayer();
    _playerConductorHaCancelado = AudioPlayer();
  }


  // Método para verificar la conexión a Internet y mostrar el Snackbar si no hay conexión
  Future<void> checkConnectionAndShowSnackbar() async {
    await connectionService.checkConnectionAndShowCard(context, () {
      refresh();
    });
  }


  void checkTravelStatus() async {
    Stream<DocumentSnapshot> stream = _travelInfoProvider.getByIdStream(_authProvider.getUser()!.uid);
    _streamTravelController = stream.listen((DocumentSnapshot document) {
      if (document.data() == null) return;
      travelInfo = TravelInfo.fromJson(document.data() as Map<String, dynamic>);
      if (travelInfo == null) return;
      switch (travelInfo!.status) {
        case 'accepted':
          addMarker('from', travelInfo!.fromLat, travelInfo!.fromLng, 'Recoger aquí', '', fromMarker);
          currentStatus = 'Viaje aceptado';
          pickupTravel();
          break;
        case 'driver_on_the_way':
          currentStatus = 'Conductor en camino';
          addMarker('from', travelInfo!.fromLat, travelInfo!.fromLng, 'Recoger aquí', '', fromMarker);
          break;
        case 'driver_is_waiting':
          cambiarestadoNotificado();
          currentStatus = 'El Conductor ha llegado';
          addMarker('from', travelInfo!.fromLat, travelInfo!.fromLng, 'Recoger aquí', '', fromMarker);
          break;
        case 'client_notificado':
          soundTaxiHaLlegado('assets/audio/tu_taxi_ha_llegado.mp3');
          currentStatus = 'El Conductor ha llegado';
          addMarker('from', travelInfo!.fromLat, travelInfo!.fromLng, 'Recoger aquí', '', fromMarker);
          break;
        case 'started':
          currentStatus = 'El Viaje ha iniciado';
          startTravel();
          break;
        case 'cancelByDriverAfterAccepted':
          Navigator.pushReplacementNamed(context, 'map_client');
          _soundConductorHaCancelado();
          _actualizarIsTravelingFalse();
          Snackbar.showSnackbar(context, 'El conductor canceló el servicio');

          break;
        case 'cancelTimeIsOver':
          Navigator.pushReplacementNamed(context, 'map_client');
          _soundConductorHaCancelado();
          _actualizarIsTravelingFalse();
          Snackbar.showSnackbar(context,  'El conductor canceló el servicio por tiempo de espera cumplido');
          break;
        case 'finished':
          currentStatus = 'Viaje finalizado';
          finishTravel();
          break;
        default:
          break;
      }
      refresh();
    });
  }


  Future<void> soundTaxiHaLlegado([
    String audioPath = 'assets/audio/tu_taxi_ha_llegado.mp3',
  ]) async {
    if (_audioTaxiLlegadoYaReproducido) return; // evita repetir
    _audioTaxiLlegadoYaReproducido = true;

    try {
      await _playerTaxiHaLlegado.stop();
      await _playerTaxiHaLlegado.setAsset(audioPath);
      await _playerTaxiHaLlegado.play();
    } catch (e) {
      if (kDebugMode) print('sound error: $e');
    }
  }

  Future<void> _soundConductorHaCancelado([
    String audioPath = 'assets/audio/el_conductor_cancelo_el_servicio.wav',
  ]) async {
    if (_audioConductorHaCanceladoYaReproducido) return; // evita repetir
    _audioConductorHaCanceladoYaReproducido = true;

    try {
      await _playerConductorHaCancelado.stop();
      await _playerConductorHaCancelado.setAsset(audioPath);
      await _playerConductorHaCancelado.play();
    } catch (e) {
      if (kDebugMode) print('sound error: $e');
    }
  }

  void cambiarestadoNotificado(){
    Map<String, dynamic> data = {'status': 'client_notificado'};
    _travelInfoProvider.update(data, _authProvider.getUser()!.uid);
  }

  void dispose() {
    _streamLocationController?.cancel();
    _streamLocationController = null;

    _streamTravelController?.cancel();
    _streamTravelController = null;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    // ✅ CLAVE: limpiar overlay + listener interno del ConnectionService
    connectionService.dispose();

    _playerTaxiHaLlegado.dispose();
    _playerConductorHaCancelado.dispose();
  }



  void _getTravelInfo() async {
    // Obtener la información del viaje del proveedor de información de viaje
    travelInfo = await _travelInfoProvider.getById(_authProvider.getUser()!.uid);
    // Configurar la posición inicial en la ubicación de destino (to)
    animateCameraToPosition(travelInfo!.fromLat, travelInfo!.fromLng);
    // Obtener información del conductor y ubicación del conductor
    getDriverInfo(travelInfo!.idDriver);
    getClientInfo();
    getDriverLocation(travelInfo!.idDriver);

  }

  void cancelTravelByClient() {
    Map<String, dynamic> data = {
      'status': 'cancelTravelByClient',
    };
    _travelInfoProvider.update(data, _authProvider.getUser()!.uid);
    _actualizarIsTravelingFalse ();
    _deleteTravelInfo();
    actualizarContadorCancelaciones();
    // Navegación y cierre del AlertDialog
    Navigator.pushNamedAndRemoveUntil(
      context,
      'map_client', // La ruta de la pantalla a la que quieres navegar
          (route) => false, // La condición para eliminar rutas anteriores (en este caso, siempre false para borrar todas las rutas)
    ).then((_) {
      // Asegura cerrar el diálogo después de que se complete la navegación
      Navigator.pop(context);
    });
  }

  void _deleteTravelInfo() async {
    try {
      await _travelInfoProvider.delete(_authProvider.getUser()!.uid);
    } catch (e) {
      if (kDebugMode) {
        print('Error al borrar el documento: $e');
      }
    }
  }

  void actualizarContadorDeViajes () async {
    int? numeroDeViajes = client?.the19Viajes;
    int nuevoContador = numeroDeViajes! + 1;
    Map<String, dynamic> data = {
      '19_Viajes': nuevoContador};
    await _clientProvider.update(data, _authProvider.getUser()!.uid);
    refresh();
  }

  void actualizarContadorCancelaciones () async {
    int? numeroCancelaciones = client?.the22Cancelaciones;
    int nuevoContadorCancelaciones = numeroCancelaciones! + 1;
    Map<String, dynamic> data = {
      '22_cancelaciones': nuevoContadorCancelaciones};
    await _clientProvider.update(data, _authProvider.getUser()!.uid);
    refresh();
  }

  void centerPosition() {
    if (_driverLatlng != null) {
      animateCameraToPosition(_driverLatlng!.latitude, _driverLatlng!.longitude);
    }
  }

  // void getDriverLocation(String idDriver) {
  //   final stream = _geofireProvider.getLocationByIdStream(idDriver);
  //
  //   _streamLocationController = stream.listen((DocumentSnapshot document) {
  //     final data = document.data() as Map<String, dynamic>?;
  //     if (data == null) return;
  //
  //     final pos = data['position'] as Map<String, dynamic>?;
  //     if (pos == null) return;
  //
  //     final geoPoint = pos['geopoint'] as GeoPoint?;
  //     if (geoPoint == null) return;
  //
  //     final headingRaw = pos['heading'];
  //     final heading = (headingRaw is num) ? headingRaw.toDouble() : 0.0;
  //
  //     final newTarget = LatLng(geoPoint.latitude, geoPoint.longitude);
  //     _driverLatlng = newTarget;
  //
  //     // ✅ actualiza SOLO el objetivo (target)
  //     _targetPos = newTarget;
  //     _targetHeading = heading;
  //
  //     // ✅ primera vez: coloca y arranca el loop suave
  //     if (_smoothPos == null) {
  //       _smoothPos = newTarget;
  //       _smoothHeading = heading;
  //
  //       addMarkerDriver(
  //         'driver',
  //         newTarget.latitude,
  //         newTarget.longitude,
  //         'Tu conductor',
  //         '',
  //         markerDriver,
  //         heading: heading,
  //       );
  //
  //       _startSmoothLoop(); // 🔥 empieza el deslizamiento continuo
  //       refresh();
  //     }
  //
  //     if (!isRouteready) {
  //       isRouteready = true;
  //       checkTravelStatus();
  //     }
  //   });
  // } para quitar el suavizado

  void getDriverLocation(String idDriver) {
    final stream = _geofireProvider.getLocationByIdStream(idDriver);

    _streamLocationController = stream.listen((DocumentSnapshot document) {
      final data = document.data() as Map<String, dynamic>?;
      if (data == null) return;

      final pos = data['position'] as Map<String, dynamic>?;
      if (pos == null) return;

      final geoPoint = pos['geopoint'] as GeoPoint?;
      if (geoPoint == null) return;

      final headingRaw = pos['heading'];
      final heading = (headingRaw is num) ? headingRaw.toDouble() : 0.0;

      final newPos = LatLng(geoPoint.latitude, geoPoint.longitude);
      _driverLatlng = newPos;

      // ✅ SIN SUAVIZADO: marker en posición real inmediatamente
      addMarkerDriver(
        'driver',
        newPos.latitude,
        newPos.longitude,
        'Tu conductor',
        '',
        markerDriver,
        heading: heading,
      );

      refresh();

      if (!isRouteready) {
        isRouteready = true;
        checkTravelStatus();
      }
    });
  }


  // double _bearingBetween(LatLng a, LatLng b) {
  //   final lat1 = a.latitude * (3.141592653589793 / 180.0);
  //   final lon1 = a.longitude * (3.141592653589793 / 180.0);
  //   final lat2 = b.latitude * (3.141592653589793 / 180.0);
  //   final lon2 = b.longitude * (3.141592653589793 / 180.0);
  //
  //   final dLon = lon2 - lon1;
  //
  //   final y = Math.sin(dLon) * Math.cos(lat2);
  //   final x = Math.cos(lat1) * Math.sin(lat2) -
  //       Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
  //
  //   var brng = Math.atan2(y, x) * (180.0 / 3.141592653589793);
  //   brng = (brng + 360.0) % 360.0;
  //   return brng;
  // }


  void pickupTravel () {
    if(!isPickUpTravel){
      isPickUpTravel = true;
      LatLng from = LatLng(_driverLatlng!.latitude, _driverLatlng!.longitude);
      LatLng to = LatLng(travelInfo!.fromLat, travelInfo!.fromLng);
      setPolylines(from, to);
    }
  }

  void startTravel() {
    if(!isStartTravel){
      isStartTravel= true;
      polylines = {};
      points = List.from([]);
      markers.removeWhere((key, marker) => marker.markerId.value == 'from');
      addMarker('to', travelInfo!.toLat, travelInfo!.toLng, 'Destino', '', toMarker);
      _from = LatLng(_driverLatlng!.latitude, _driverLatlng!.longitude);
      _to = LatLng(travelInfo!.toLat, travelInfo!.toLng);
      setPolylines(_from!, _to!);
      refresh();
    }
  }

  void finishTravel(){
    if(!isFinishtTravel){
      isFinishtTravel = true;
      _actualizarIsTravelingFalse ();
      actualizarContadorDeViajes();
      Navigator.pushNamedAndRemoveUntil(context, 'travel_calification_page', (route) => false, arguments: travelInfo!.idTravelHistory);
    }
  }

  void getDriverInfo(String id) async {
    driver = await _driverProvider.getById(id);
    refresh();
  }

  void getClientInfo() async {
    client = await _clientProvider.getById(_authProvider.getUser()!.uid);
  }

  void _actualizarIsTravelingTrue () async {
    Map<String, dynamic> data = {
      '00_is_traveling': true};
    await _clientProvider.update(data, _authProvider.getUser()!.uid);
    refresh();
  }

  void _actualizarIsTravelingFalse () async {
    Map<String, dynamic> data = {
      '00_is_traveling': false};
    await _clientProvider.update(data, _authProvider.getUser()!.uid);
    refresh();
  }

  Future<void> setPolylines(LatLng from, LatLng to) async {
    final ok = await connectionService.hasInternetConnection();
    if (!ok) {
      if(context.mounted){
        await connectionService.checkConnectionAndShowCard(context, () {
          refresh();
        });
      }
      return;
    }


    try {
      points = List.from([]);

      final res = await _functions.httpsCallable('getDirections').call({
        'fromLat': from.latitude,
        'fromLng': from.longitude,
        'toLat': to.latitude,
        'toLng': to.longitude,
        'mode': 'driving',
      });

      final data = Map<String, dynamic>.from(res.data);

      if (data['ok'] != true) {
        if (kDebugMode) print('getDirections failed: $data');
        return;
      }

      final encoded = (data['polyline'] ?? '').toString();
      if (encoded.isEmpty) return;

      // ✅ Decodificar polyline
      final decoded = PolylinePoints().decodePolyline(encoded);
      points = decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();

      // ✅ Reemplazar polylines (para evitar que se acumulen)
      polylines = {
        Polyline(
          polylineId: const PolylineId('poly'),
          color: Colors.black87,
          points: points,
          width: 4,
        )
      };

      refresh();
    } catch (e) {
      if (kDebugMode) print('setPolylines (function) error: $e');
    }
  }

  // void onMapCreated(GoogleMapController controller){
  //   controller.setMapStyle(utilsMap.mapStyle);
  //   _mapController.complete(controller);
  //   _getTravelInfo();
  // } 8 feb 2026


  void onMapCreated(GoogleMapController controller) {
    controller.setMapStyle(utilsMap.mapStyle);

    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }

    if (_didLoadTravel) return;   // ✅ evita duplicar listeners
    _didLoadTravel = true;

    _getTravelInfo();
  }


  void checkGPS() async{
    bool islocationEnabled = await Geolocator.isLocationServiceEnabled();
    if(islocationEnabled){
      if (kDebugMode) {
        print('GPS activado');
      }
    }
    else{
      bool locationGPS = await location.Location().requestService();
      if(locationGPS){
        if (kDebugMode) {
          print(' el usuario activo el GPS');
        }
      }
    }
  }


  Future? animateCameraToPosition(double latitude, double longitude)  async {
    GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
            bearing: 0,
            target: LatLng(latitude,longitude),
            zoom: 15.1)
    )
    );
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
      BitmapDescriptor iconMarker,

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
        double heading = 0.0, // ✅ nuevo
      }) {
    MarkerId id = MarkerId(markerId);

    Marker marker = Marker(
      markerId: id,
      icon: iconMarker,
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(title: title, snippet: content),
      draggable: false,
      zIndex: 2,
      flat: true,                  // ✅ necesario para rotación
      rotation: heading,           // ✅ aquí gira
      anchor: const Offset(0.5, 0.5), // ✅ centro para “carrito”
    );

    markers[id] = marker;
  }


  void openBottomSheetDiverInfo(){
    showModalBottomSheet(
        context: context,
        builder: (context)=> BottomSheetDriverInfo(
          imageUrl: driver?.image ?? '',
          name:driver?.the01Nombres ?? '',
          apellido: driver?.the02Apellidos ?? '',
          celular: driver?.the07Celular ?? '',
          numeroViajes: driver?.the30NumeroViajes ?? 0,
          placa: driver?.the18Placa ?? '',
          color: driver?.the16Color ?? '',
          servicio: driver?.the19TipoServicio ?? '',
          marca: driver?.the15Marca ?? '',
          idDriver: driver?.id ?? '',
          clase: driver?.the14TipoVehiculo ?? "",
        ));
  }

}
