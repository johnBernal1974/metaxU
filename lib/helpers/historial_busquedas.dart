
import 'package:shared_preferences/shared_preferences.dart';

class TravelHistory {
  static Future<List<String>> getTravelHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('travel_history') ?? [];
  }

  static Future<void> saveTravelHistory(List<String> history) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('travel_history', history);
  }
}
