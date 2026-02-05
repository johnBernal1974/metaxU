import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/client_history_provider.dart';
import 'package:apptaxis/models/travel_history_index.dart';

class HistorialViajesController {
  late BuildContext context;
  late Function refresh;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  final MyAuthProvider _authProvider = MyAuthProvider();
  final ClientHistoryProvider _clientHistoryProvider = ClientHistoryProvider();

  Future? init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    refresh();
  }

  // ✅ Paginar desde Clients/{uid}/history

  Future<Map<String, dynamic>> getPaginatedThisWeek({
    required DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    final user = _authProvider.getUser();
    if (user == null) {
      return {'items': <TravelHistoryIndex>[], 'lastDoc': null, 'hasMore': false};
    }

    // Semana: lunes 00:00 a lunes siguiente 00:00
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final endExclusive = start.add(const Duration(days: 7));

    final res = await _clientHistoryProvider.getPaginatedByDateRange(
      clientId: user.uid,
      start: start,
      endExclusive: endExclusive,
      lastDoc: lastDoc,
      limit: limit,
    );

    final List<TravelHistoryIndex> items = [];
    for (final doc in (res['docs'] as List<DocumentSnapshot>)) {
      final raw = doc.data();
      if (raw == null) continue;
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['finalViaje'] == null) continue;
      try {
        items.add(TravelHistoryIndex.fromDoc(doc.id, data));
      } catch (_) {}
    }

    return {
      'items': items,
      'lastDoc': res['lastDoc'] as DocumentSnapshot?,
      'hasMore': res['hasMore'] as bool,
    };
  }


  Future<List<Map<String, dynamic>>> getYearMonthlySummary(int year) async {
    final user = _authProvider.getUser();
    if (user == null) return [];

    final snap = await FirebaseFirestore.instance
        .collection('Clients')
        .doc(user.uid)
        .collection('history_monthly')
        .where('year', isEqualTo: year)
        .orderBy('month')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return {
        'yearMonth': (data['yearMonth'] ?? d.id).toString(),
        'year': data['year'] ?? year,
        'month': data['month'] ?? 1,
        'totalTrips': data['totalTrips'] ?? 0,
        'totalAmount': data['totalAmount'] ?? 0,
      };
    }).toList();
  }



  Future<Map<String, dynamic>> getPaginated({
    required String yearMonth,
    required DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    final user = _authProvider.getUser();
    if (user == null) {
      return {'items': <TravelHistoryIndex>[], 'lastDoc': null, 'hasMore': false};
    }

    final res = await _clientHistoryProvider.getPaginated(
      clientId: user.uid,
      yearMonth: yearMonth,
      lastDoc: lastDoc,
      limit: limit,
    );

    final List<TravelHistoryIndex> items = [];

    for (final doc in (res['docs'] as List<DocumentSnapshot>)) {
      final raw = doc.data();
      if (raw == null) continue;

      final data = Map<String, dynamic>.from(raw as Map);

      if (data['finalViaje'] == null) continue;

      try {
        items.add(TravelHistoryIndex.fromDoc(doc.id, data));
      } catch (_) {}
    }

    return {
      'items': items,
      'lastDoc': res['lastDoc'] as DocumentSnapshot?,
      'hasMore': res['hasMore'] as bool,
    };
  }

  Future<void> hideFromMyHistory(String idTravelHistory) async {
    final user = _authProvider.getUser();
    if (user == null) return;

    await _clientHistoryProvider.hideFromHistory(
      clientId: user.uid,
      travelId: idTravelHistory, // ⚠️ si tu provider hace .doc(travelId)
    );
  }

  void goToDetailHistory(String idTravelHistory) {
    Navigator.pushNamed(context, 'detail_history_page', arguments: idTravelHistory);
  }

}
