import 'package:cloud_functions/cloud_functions.dart';

class PlacesFunctionsService {
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<List<Map<String, String>>> autocomplete(String input) async {
    final res = await _functions.httpsCallable('placesAutocomplete').call({
      'input': input,
      'country': 'co',
    });

    final data = Map<String, dynamic>.from(res.data);
    if (data['ok'] != true) return [];

    final list = (data['predictions'] as List? ?? []);
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return {
        'placeId': (m['placeId'] ?? '').toString(),
        'description': (m['description'] ?? '').toString(),
      };
    }).where((p) => p['placeId']!.isNotEmpty && p['description']!.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>?> details(String placeId) async {
    final res = await _functions.httpsCallable('placeDetails').call({
      'placeId': placeId,
    });
    final data = Map<String, dynamic>.from(res.data);
    if (data['ok'] != true) return null;
    return data;
  }
}
