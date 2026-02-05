import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../providers/driver_provider.dart';
import '../../../../providers/travel_history_provider.dart';
import '../../../models/driver.dart';
import '../../../models/travelHistory.dart';

class DetailHistoryController {
  late BuildContext context;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  late Function refresh;

  late TravelHistoryProvider _travelHistoryProvider;
  late DriverProvider _driverProvider;

  String? idTravelHistory;
  TravelHistory? travelHistory;
  Driver? driver;

  Future<void> init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;

    _travelHistoryProvider = TravelHistoryProvider();
    _driverProvider = DriverProvider();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null) {
      // no llegó id
      refresh();
      return;
    }

    idTravelHistory = args.toString(); // ✅ soporta String/int/etc

    await getTravelHistoryInfo(); // ✅ importante
  }

  Future<void> getTravelHistoryInfo() async {
    if (idTravelHistory == null || idTravelHistory!.isEmpty) return;

    final history = await _travelHistoryProvider.getById(idTravelHistory!);
    if (history == null) {
      refresh();
      return;
    }

    travelHistory = history;

    final idDriver = (travelHistory?.idDriver ?? '').toString();
    if (idDriver.isEmpty) {
      refresh();
      return;
    }

    await getDriverInfo(idDriver);
  }

  Future<void> getDriverInfo(String idDriver) async {
    final d = await _driverProvider.getById(idDriver);
    driver = d; // ✅ sin ! (evita crash si viene null)
    refresh();
  }
}
