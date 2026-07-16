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

import '../../../utils/marker_utils.dart';

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
  bool _isMarkersLoaded = false;


  Future<void> init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;

    _geofireProvider = GeofireProvider();
    _authProvider = MyAuthProvider();
    _driverProvider = DriverProvider();
    _clientProvider = ClientProvider();
    _travelInfoProvider = TravelInfoProvider();

    // =========================================================================
    // 🔥 CARGA DINÁMICA DE MARCADORES USANDO HELPER (MarkerUtils)
    // =========================================================================
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Usamos el mismo helper que en TravelInfoController para mantener consistencia
    markerDriver = await MarkerUtils.getMarkerFromAsset('assets/marker_taxi.png', pixelRatio, 11.0);
    fromMarker = await MarkerUtils.getMarkerFromAsset('assets/ubicacion_client.png', pixelRatio, 13.0);
    toMarker = await MarkerUtils.getMarkerFromAsset('assets/marker_destino.png', pixelRatio, 13.0);
    // =========================================================================

    _isMarkersLoaded = true;
    checkGPS();

    await checkConnectionAndShowSnackbar();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((_) async {
      await checkConnectionAndShowSnackbar();

      if (travelInfo?.status == 'accepted' && !isPickUpTravel) {
        pickupTravel();
      }
      if (travelInfo?.status == 'started' && !isStartTravel) {
        startTravel();
      }

      if (context.mounted) {
        refresh();
      }
    });

    // Nota: Mantenemos la lógica de isTraveling en true,
    // pero recuerda que esto se ejecutará siempre que entres al mapa de viaje.
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

      if (!_isMarkersLoaded) return;

      if (document.data() == null) return;

      travelInfo = TravelInfo.fromJson(document.data() as Map<String, dynamic>);
      if (travelInfo == null) return;

      switch (travelInfo!.status) {
        case 'accepted':
        // 🔥 Aseguramos que el estado esté en true al ser aceptado
          _actualizarIsTravelingTrue();

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
          currentStatus = 'Conductor en camino';
          addMarker('from', travelInfo!.fromLat, travelInfo!.fromLng, 'Recoger aquí', '', fromMarker);
          break;

        case 'driver_is_waiting':
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
          currentStatus = 'El Viaje ha iniciado';
          startTravel();
          break;

        case 'cancelByDriverAfterAccepted':
        case 'cancelTimeIsOver':
        // 🔥 GUARDAMOS EL STATUS EN UNA VARIABLE LOCAL ANTES DE BORRAR
          final String statusCancelacion = travelInfo!.status;
          final String userId = _authProvider.getUser()!.uid;

          try {
            // 1. Limpiamos el estado en la DB
            await _actualizarIsTravelingFalse();

            // 2. BORRAMOS el documento de la colección activa
            await _travelInfoProvider.delete(userId);
          } catch (e) {
            if (kDebugMode) print("❌ Error al limpiar viaje: $e");
          } finally {
            // 3. USAMOS LA VARIABLE LOCAL PARA EL SNACKBAR
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(context, 'map_client', (route) => false);

              Snackbar.showSnackbar(
                  context,
                  statusCancelacion == 'cancelByDriverAfterAccepted'
                      ? 'El conductor canceló el servicio'
                      : 'El conductor canceló el servicio por tiempo de espera cumplido'
              );
            }

            // 4. EL AUDIO SIGUE FUNCIONANDO NORMALMENTE
            // Como ya pusimos _cancelSoundPlayed = true, garantizamos que suene
            // independientemente de si el documento existe o no.
            if (!_cancelSoundPlayed) {
              _cancelSoundPlayed = true;
              SoundManager().playCancelacionConductor();
            }
          }
          break;

        case 'finished':
          currentStatus = 'Viaje finalizado';

          // 🔥 IMPORTANTE: Validamos antes de llamar
          if (!isFinishtTravel) {
            finishTravel();
          }
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
    // 1. Obtenemos el documento desde Firestore
    travelInfo = await _travelInfoProvider.getById(_authProvider.getUser()!.uid);

    // 2. SEGURIDAD: Si el viaje no existe en la base de datos
    if (travelInfo == null) {
      print("⚠️ Viaje inexistente detectado, forzando limpieza de estado...");
      await _actualizarIsTravelingFalse();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, 'map_client', (route) => false);
      }
      return;
    }

    // 3. 🔥 PARCHE DE SEGURIDAD: Detectar "Viajes Fantasma" (Bloqueos)
    // Si el viaje está en estado 'created' pero no tiene conductor,
    // y asumimos que ya pasó el tiempo de espera, lo eliminamos.
    if (travelInfo!.status == 'created' && (travelInfo!.idDriver == null || travelInfo!.idDriver == "")) {
      print("🧹 Viaje fantasma o bloqueado detectado. Limpiando datos...");

      // Borramos el documento de la colección TravelInfo
      await _deleteTravelInfo();

      // Forzamos el estado de viaje a false en el perfil del cliente
      await _actualizarIsTravelingFalse();

      // Redirigimos al mapa principal para que el cliente pueda volver a intentar
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, 'map_client', (route) => false);
      }
      return;
    }

    // 4. Si el viaje es legítimo (tiene conductor o status válido), continuamos con la lógica normal
    animateCameraToPosition(travelInfo!.fromLat, travelInfo!.fromLng);

    // Solo pedimos información del conductor si realmente existe un ID
    if (travelInfo!.idDriver != null && travelInfo!.idDriver!.isNotEmpty) {
      getDriverInfo(travelInfo!.idDriver);
      getDriverLocation(travelInfo!.idDriver);
    }

    getClientInfo();
    checkTravelStatus();
  }

  void cancelTravelByClient() async {
    Map<String, dynamic> data = {'status': 'cancelTravelByClient'};

    // Esperamos a que Firebase confirme la actualización del estatus
    await _travelInfoProvider.update(data, _authProvider.getUser()!.uid);

    // Esperamos a que Firebase confirme que ya no está viajando
    await _actualizarIsTravelingFalse();

    await _deleteTravelInfo();

    if(context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, 'map_client', (route) => false);
    }
  }

  Future<void> _deleteTravelInfo() async {
    try {
      await _travelInfoProvider.delete(_authProvider.getUser()!.uid);
    } catch (e) {
      if (kDebugMode) print('Error al borrar el documento: $e');
    }
  }

  void actualizarContadorDeViajes() async {
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

      if (!_isMarkersLoaded) return;

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

        isRouteready = true;

        if (travelInfo?.status == 'started') {

          startTravel();
        }

        if (travelInfo?.status == 'accepted' ||
            travelInfo?.status == 'driver_on_the_way') {
          pickupTravel();
        }
      }
    });
  }

  Future<void> _moveCameraSmooth(LatLng position) async {
    try {

      if (!_mapController.isCompleted) return;

      final controller = await _mapController.future;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 16,
            bearing: 0,
            tilt: 0,
          ),
        ),
      );

    } catch (e) {
      print("⚠️ Error animateCamera: $e");
    }
  }

  void pickupTravel() {

    if (_driverLatlng == null) return;

    if (isPickUpTravel) return;

    LatLng from = LatLng(
      _driverLatlng!.latitude,
      _driverLatlng!.longitude,
    );

    LatLng to = LatLng(
      travelInfo!.fromLat,
      travelInfo!.fromLng,
    );

    setPolylines(from, to).then((routeCreated) {

      if (routeCreated) {
        isPickUpTravel = true;
      }

    });
  }

  Future<void> startTravel() async {

    if (_driverLatlng == null) {
      return;
    }

    if (isStartTravel) {
      return;
    }

    polylines.clear();

    points.clear();

    markers.removeWhere(
          (key, marker) =>
      marker.markerId.value == 'from',
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

    bool routeCreated = await setPolylines(
      _from!,
      _to!,
    );

    if (routeCreated) {
      isStartTravel = true;
    }

    refresh();
  }

  void finishTravel() async { // 1. Convertimos a async
    if (!isFinishtTravel) {
      isFinishtTravel = true;

      // 2. 🔥 CAPTURAMOS DATOS CRÍTICOS ANTES DE CUALQUIER BORRADO
      final String userId = _authProvider.getUser()!.uid;
      final String idHistorial = travelInfo?.idTravelHistory ?? '';

      // 3. LIMPIEZA DE BASE DE DATOS
      try {
        // Marcamos al cliente como "no viajando"
        await _actualizarIsTravelingFalse();

        // Borramos el documento de la colección activa de viajes
        await _travelInfoProvider.delete(userId);

      } catch (e) {
        if (kDebugMode) print("❌ Error al limpiar viaje al finalizar: $e");
      }

      // 4. Limpieza de UI (Esto no depende de Firebase, puede ir después)
      polylines.clear();
      points.clear();
      markers.clear();

      // 5. Lógica de negocio
      actualizarContadorDeViajes();

      // 6. NAVEGACIÓN (Usamos la variable local idHistorial que capturamos al principio)

      if(context.mounted){
        Navigator.pushNamedAndRemoveUntil(
          context,
          'travel_calification_page',
              (route) => false,
          arguments: idHistorial,
        );
      }
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

  Future<void> _actualizarIsTravelingFalse() async {
    Map<String, dynamic> data = {'00_is_traveling': false};
    await _clientProvider.update(data, _authProvider.getUser()!.uid);
    refresh();
  }

  Future<bool> setPolylines(
      LatLng from,
      LatLng to,
      ) async {

    final ok = await connectionService.hasInternetConnection();

    if (!ok) {
      return false;
    }

    try {

      points = [];

      final res = await _functions
          .httpsCallable('getDirections')
          .call({
        'fromLat': from.latitude,
        'fromLng': from.longitude,
        'toLat': to.latitude,
        'toLng': to.longitude,
        'mode': 'driving',
      });

      final data = Map<String, dynamic>.from(res.data);

      if (data['ok'] != true) {
        return false;
      }

      final encoded = data['polyline'];

      final decoded =
      PolylinePoints().decodePolyline(encoded);

      points = decoded
          .map((p) => LatLng(
        p.latitude,
        p.longitude,
      ))
          .toList();

      polylines = {
        Polyline(
          polylineId: const PolylineId('poly'),
          points: points,
          color: Colors.black87,
          width: 4,
        )
      };

      refresh();

      return true;

    } catch (e) {

      print(e);

      return false;
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

  Future<void> animateCameraToPosition(
      double latitude,
      double longitude,
      ) async {

    try {

      if (!_mapController.isCompleted) {
        return;
      }

      final controller = await _mapController.future;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            bearing: 0,
            target: LatLng(latitude, longitude),
            zoom: 15.1,
          ),
        ),
      );

    } catch (e) {

      if (kDebugMode) {
        print('⚠️ animateCameraToPosition: $e');
      }

    }
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