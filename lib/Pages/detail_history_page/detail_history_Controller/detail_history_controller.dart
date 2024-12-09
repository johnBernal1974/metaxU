
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../providers/driver_provider.dart';
import '../../../../providers/travel_history_provider.dart';
import '../../../models/driver.dart';
import '../../../models/travelHistory.dart';

class DetailHistoryController{
  late BuildContext context;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  late Function refresh;
  late TravelHistoryProvider _travelHistoryProvider;
  late DriverProvider _driverProvider;
  String? idTravelHistory;
  TravelHistory? travelHistory;
  Driver? driver;

  Future? init (BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    _travelHistoryProvider = TravelHistoryProvider();
    _driverProvider = DriverProvider();

    idTravelHistory = ModalRoute.of(context)?.settings.arguments as String;

    getTravelHistoryInfo ();

  }
  void getTravelHistoryInfo () async {
    TravelHistory? history = await _travelHistoryProvider.getById(idTravelHistory!);
    if (history != null) {
      travelHistory = history;
      getDriverInfo(travelHistory?.idDriver ?? '');
    }
  }

  void getDriverInfo(String idDriver) async {
    driver = (await _driverProvider.getById(idDriver))!;
    refresh();
  }

}