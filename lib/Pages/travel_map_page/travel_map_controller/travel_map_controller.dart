import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location;
import '../../../../providers/auth_provider.dart';
import '../../../../providers/client_provider.dart';
import '../../../../providers/driver_provider.dart';
import '../../../../providers/geofire_provider.dart';
import '../../../../providers/travel_info_provider.dart';
import '../../../helpers/bottom_sheet_driver_info.dart';
import '../../../helpers/conectivity_service.dart';
import '../../../helpers/snackbar.dart';
import '../../../helpers/sound_manager.dart';
import '../../../models/driver.dart';
import '../../../models/travel_info.dart';
import 'package:apptaxis/models/client.dart';
import 'package:apptaxis/utils/utilsMap.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:io';

class TravelMapController{
  late BuildContext context;
  late Function refresh;
  bool isMoto = false;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _mapController = Completer();
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  CameraPosition initialPosition = const CameraPosition(
    target: LatLng(4.3445324, -74.3639381),
    zoom: 16.0,
  );
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  late BitmapDescriptor markerDriver;
  late GeofireProvider _geofireProvider;
  late MyAuthProvider _authProvider;
  late DriverProvider _driverProvider;
  late ClientProvider _clientProvider;
  bool isConected = true;

  StreamSubscription<DocumentSnapshot<Object?>>? _streamLocationController;
  StreamSubscription<DocumentSnapshot<Object?>>? _streamTravelController;

  bool soundIsaceptado = false;
  bool _cancelSoundPlayed = false;
  bool _followDriver = true;

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
  Set<Polyline> polylines ={};
  List<LatLng> points = List.from([]);
  LatLng? _from;
  LatLng? _to;
  LatLng? get from => _from;
  LatLng? get to => _to;
  final ConnectionService connectionService = ConnectionService();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  //evitar traergetdriverinfo dos veces
  bool _didLoadTravel = false;

  //para calificacion
  double? ratingAvg;
  int ratingCount = 0;

  bool _soundTaxiLlegadaPlayed = false;

  // Agrega esta variable para controlar la distancia mínima
  LatLng? _lastPolylineLocation;

  // =========================================================================
  // CORREGIDO: Un solo método init limpio y sin funciones duplicadas por dentro
  // =========================================================================
  Future? init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    _geofireProvider = GeofireProvider();
    _authProvider = MyAuthProvider();
    _driverProvider = DriverProvider();
    _clientProvider = ClientProvider();
    _travelInfoProvider = TravelInfoProvider();

    // =========================================================================
    // 🔥 AJUSTE DINÁMICO DE MARCADORES (CON VALORES FINOS CALIBRADOS)
    // =========================================================================
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Valores pequeños para conservar la estética compacta que te gustó
    double baseDriver = 11.0;
    double baseClient = 13.0;
    double baseDestino = 13.0;

    if (Platform.isIOS) {
      baseDriver = 11.0;
      baseClient = 13.0;
      baseDestino = 13.0;
    } else if (Platform.isAndroid) {
      baseDriver = 11.0;
      baseClient = 13.0;
      baseDestino = 13.0;
    }

    int finalWidthDriver = (baseDriver * pixelRatio).round();
    int finalWidthClient = (baseClient * pixelRatio).round();
    int finalWidthDestino = (baseDestino * pixelRatio).round();

    markerDriver = await createMarkerImageFromAssets('assets/marker_taxi.png', finalWidthDriver);
    fromMarker = await createMarkerImageFromAssets('assets/ubicacion_client.png', finalWidthClient);
    toMarker = await createMarkerImageFromAssets('assets/marker_destino.png', finalWidthDestino);
    // =========================================================================

    checkGPS();
    await checkConnectionAndShowSnackbar();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((_) async {

          await checkConnectionAndShowSnackbar();

          if (context.mounted) {
            refresh();
          }
        });

    _actualizarIsTravelingTrue();
    _position = await Geolocator.getCurrentPosition();
    if (_position != null) {
      initialPosition = CameraPosition(
        target: LatLng(_position!.latitude, _position!.longitude),
        zoom: 20.0,
      );
    }
  }

  // Método para verificar la conexión a Internet y mostrar el Snackbar si no hay conexión
  Future<void> checkConnectionAndShowSnackbar() async {
    await connectionService.checkConnectionAndShowCard(context, () {
      refresh();
    });
  }

  void checkTravelStatus() async {
    Stream<DocumentSnapshot> stream = _travelInfoProvider.getByIdStream(_authProvider.getUser()!.uid);
    _streamTravelController = stream.listen((DocumentSnapshot document) async {

      if (document.data() == null) {
        return;
      }
      travelInfo = TravelInfo.fromJson(document.data() as Map<String, dynamic>);
      if (travelInfo == null) return;
      switch (travelInfo!.status) {
        case 'accepted':
          currentStatus = 'Viaje aceptado';
          addMarker('from', travelInfo!.fromLat, travelInfo!.fromLng, 'Recoger aquí', '', fromMarker);
          refresh();

          if (!soundIsaceptado) {
            soundIsaceptado = true;
            SoundManager().playServicioAceptado();
          }
          pickupTravel();
          break;
        case 'driver_on_the_way':
          print("✅ driver_on_the_way");
          currentStatus = 'Conductor en camino';
          addMarker('from', travelInfo!.fromLat, travelInfo!.fromLng, 'Recoger aquí', '', fromMarker);
          break;
        case 'driver_is_waiting':
          print("✅ driver_is_waiting");
          cambiarestadoNotificado();
          currentStatus = 'El Conductor ha llegado';
          addMarker('from', travelInfo!.fromLat, travelInfo!.fromLng, 'Recoger aquí', '', fromMarker);
          break;
        case 'client_notificado':
          if (!_soundTaxiLlegadaPlayed) {
            _soundTaxiLlegadaPlayed = true;
            await SoundManager().playTaxiLlegada();
          }
          currentStatus = 'El Conductor ha llegado';
          addMarker('from', travelInfo!.fromLat, travelInfo!.fromLng, 'Recoger aquí', '', fromMarker);
          break;
        case 'started':
          print("✅ started");
          print("🔥 POLYLINES ACTUALES: ${polylines.length}");
          currentStatus = 'El Viaje ha iniciado';
          startTravel();
          break;
        case 'cancelByDriverAfterAccepted':
          if(context.mounted){
            Navigator.pushReplacementNamed(context, 'map_client');
          }
          _actualizarIsTravelingFalse();
          if(context.mounted){
            Snackbar.showSnackbar(context, 'El conductor canceló el servicio');
          }
          if (!_cancelSoundPlayed) {
            _cancelSoundPlayed = true;
            SoundManager().playCancelacionConductor();
          }
          break;
        case 'cancelTimeIsOver':
          if(context.mounted){
            Navigator.pushReplacementNamed(context, 'map_client');
          }
          _actualizarIsTravelingFalse();
          if(context.mounted){
            Snackbar.showSnackbar(context, 'El conductor canceló el servicio por tiempo de espera cumplido');
          }
          if (!_cancelSoundPlayed) {
            _cancelSoundPlayed = true;
            SoundManager().playCancelacionConductor();
          }
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
    connectionService.dispose();
  }

  void _getTravelInfo() async {
    travelInfo = await _travelInfoProvider.getById(_authProvider.getUser()!.uid);
    animateCameraToPosition(travelInfo!.fromLat, travelInfo!.fromLng);
    getDriverInfo(travelInfo!.idDriver);
    getClientInfo();
    checkTravelStatus();
    getDriverLocation(travelInfo!.idDriver);
  }

  void cancelTravelByClient() {
    Map<String, dynamic> data = {'status': 'cancelTravelByClient'};
    _travelInfoProvider.update(data, _authProvider.getUser()!.uid);
    _actualizarIsTravelingFalse ();
    _deleteTravelInfo();
    actualizarContadorCancelaciones();
    Navigator.pushNamedAndRemoveUntil(context, 'map_client', (route) => false).then((_) {
      Navigator.pop(context);
    });
  }

  void _deleteTravelInfo() async {
    try {
      await _travelInfoProvider.delete(_authProvider.getUser()!.uid);
    } catch (e) {
      if (kDebugMode) print('Error al borrar el documento: $e');
    }
  }

  void actualizarContadorDeViajes() async {
    try {
      await FirebaseFirestore.instance
          .collection('Clients')
          .doc(_authProvider.getUser()!.uid)
          .update({'19_Viajes': FieldValue.increment(1)});
      print('✅ Viaje incrementado');
    } catch (e) {
      print('❌ Error incrementando viajes: $e');
    }
    refresh();
  }

  void actualizarContadorCancelaciones () async {
    int? numeroCancelaciones = client?.cancelaciones;
    int nuevoContadorCancelaciones = numeroCancelaciones! + 1;
    Map<String, dynamic> data = {'22_cancelaciones': nuevoContadorCancelaciones};
    await _clientProvider.update(data, _authProvider.getUser()!.uid);
    refresh();
  }

  void centerPosition() {
    if (_driverLatlng != null) {
      animateCameraToPosition(_driverLatlng!.latitude, _driverLatlng!.longitude);
    }
  }

  void getDriverLocation(String idDriver) {
    final stream = _geofireProvider.getLocationByIdStream(idDriver);

    _streamLocationController = stream.listen((DocumentSnapshot document) {
      final data = document.data() as Map<String, dynamic>?;
      if (data == null) return;

      final pos = data['position'] as Map<String, dynamic>?;
      if (pos == null) return;

      final geoPoint = pos['geopoint'] as GeoPoint?;
      if (geoPoint == null) return;

      final headingRaw = data['heading'];
      final heading = (headingRaw is num) ? headingRaw.toDouble() : 0.0;

      final newPos = LatLng(geoPoint.latitude, geoPoint.longitude);
      _driverLatlng = newPos;
      if (_followDriver) {
        _moveCameraSmooth(newPos);
      }

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

        print("📍 Primera ubicación recibida");

        isRouteready = true;

        if (travelInfo?.status == 'started') {

          print("🔥 Reintentando startTravel");

          startTravel();
        }

        if (travelInfo?.status == 'accepted' ||
            travelInfo?.status == 'driver_on_the_way') {
          print("🔥 Reintentando pickupTravel");
          pickupTravel();
        }
      }
    });
  }

  Future<void> _moveCameraSmooth(LatLng position) async {
    try {
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 16, bearing: 0, tilt: 0),
        ),
      );
    } catch (e) {
      if (kDebugMode) print("Error moviendo cámara: $e");
    }
  }

  void pickupTravel() {
    if (_driverLatlng == null) {
      return;
    }

    if (travelInfo == null) {
      return;
    }

    if (isPickUpTravel) {
      return;
    }

    LatLng from = LatLng(
      _driverLatlng!.latitude,
      _driverLatlng!.longitude,
    );

    LatLng to = LatLng(
      travelInfo!.fromLat,
      travelInfo!.fromLng,
    );

    isPickUpTravel = true;

    setPolylines(from, to);
  }

  void startTravel() {
    print("🔥 START TRAVEL");
    print("🔥 isStartTravel = $isStartTravel");
    if (_driverLatlng == null) {
      return;
    }

    if (isStartTravel) {
      return;
    }

    polylines.clear();
    points.clear();

    markers.removeWhere(
          (key, marker) => marker.markerId.value == 'from',
    );

    addMarker(
      'to',
      travelInfo!.toLat,
      travelInfo!.toLng,
      'Destino',
      '',
      toMarker,
    );

    _from = LatLng(
      _driverLatlng!.latitude,
      _driverLatlng!.longitude,
    );

    _to = LatLng(
      travelInfo!.toLat,
      travelInfo!.toLng,
    );

    isStartTravel = true;

    setPolylines(_from!, _to!);

    refresh();
  }

  void finishTravel(){

    if(!isFinishtTravel){

      isFinishtTravel = true;

      polylines.clear();
      points.clear();
      markers.clear();

      _actualizarIsTravelingFalse();

      actualizarContadorDeViajes();

      Navigator.pushNamedAndRemoveUntil(
        context,
        'travel_calification_page',
            (route) => false,
        arguments: travelInfo!.idTravelHistory,
      );
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
    Map<String, dynamic> data = {'00_is_traveling': true};
    await _clientProvider.update(data, _authProvider.getUser()!.uid);
    refresh();
  }

  void _actualizarIsTravelingFalse () async {
    Map<String, dynamic> data = {'00_is_traveling': false};
    await _clientProvider.update(data, _authProvider.getUser()!.uid);
    refresh();
  }

  Future<void> setPolylines(LatLng from, LatLng to) async {

    // 🔥 LÓGICA DE FILTRO: Solo consultar si la distancia es mayor a 50 metros
    if (_lastPolylineLocation != null) {
      double dist = Geolocator.distanceBetween(
          _lastPolylineLocation!.latitude, _lastPolylineLocation!.longitude,
          from.latitude, from.longitude
      );
      if (dist < 50) return; // Si se movió menos de 50m, no hacemos nada
    }
    _lastPolylineLocation = from; // Actualizamos el ancla con la nueva posición
    // ========================================================

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
        print('❌ FIREBASE DEVOLVIO ERROR');
        return;
      }

      final encoded = (data['polyline'] ?? '').toString();
      if (encoded.isEmpty) return;

      final decoded = PolylinePoints().decodePolyline(encoded);
      points = decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
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

  void onMapCreated(GoogleMapController controller) {
    controller.setMapStyle(utilsMap.mapStyle);
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }
    if (_didLoadTravel) return;
    _didLoadTravel = true;
    _getTravelInfo();
  }

  void checkGPS() async{
    bool islocationEnabled = await Geolocator.isLocationServiceEnabled();
    if(islocationEnabled){
      if (kDebugMode) print('GPS activado');
    } else {
      bool locationGPS = await location.Location().requestService();
      if(locationGPS){
        if (kDebugMode) print('el usuario activo el GPS');
      }
    }
  }

  Future? animateCameraToPosition(double latitude, double longitude)  async {
    GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(bearing: 0, target: LatLng(latitude,longitude), zoom: 15.1)
    ));
  }

  Future<BitmapDescriptor> createMarkerImageFromAssets(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    ByteData? markerBuffer = await fi.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(markerBuffer!.buffer.asUint8List());
  }

  void addMarker(String markerId, double lat, double lng, String title, String content, BitmapDescriptor iconMarker) {
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

  void addMarkerDriver(String markerId, double lat, double lng, String title, String content, BitmapDescriptor iconMarker, {double heading = 0.0}) {
    MarkerId id = MarkerId(markerId);
    Marker marker = Marker(
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
          placa: travelInfo?.placa ?? 'Sin placa',
          color: travelInfo?.color ?? 'Sin color',
          servicio: " ${travelInfo?.tipoVehiculoServicio ?? ''}",
          marca: travelInfo?.marca ?? 'Sin marca',
          clase: travelInfo?.tipoVehiculo ?? 'Sin clase',
          idDriver: driver?.id ?? '',
        ));
  }
}