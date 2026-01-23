import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'client_provider.dart';

class PushNotificationsProvider {
  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;


  final StreamController<Map<String, dynamic>> _streamController = StreamController.broadcast();
  Stream get message => _streamController.stream;

  PushNotificationsProvider() {
    _firebaseMessaging = FirebaseMessaging.instance;
    _initializeNotifications();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void initPushNotifications() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _streamController.sink.add(message.data);

      // Mostrar una notificación local
      _showLocalNotification(message.notification?.title, message.notification?.body, message.data);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _streamController.sink.add(message.data);
    });
  }

  Future<void> _showLocalNotification(String? title, String? body, Map<String, dynamic> data) async {
    // Extract data from the payload
    String data1 = data['data1'] ?? 'N/A';
    String data2 = data['data2'] ?? 'N/A';
    String data3 = data['data3'] ?? 'N/A';

    // Create a notification with buttons
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      '$body\n\nData 1: $data1\nData 2: $data2\nData 3: $data3', // Cuerpo de la notificación
      platformChannelSpecifics,
    );

  }

  void saveToken(String? idUser) async {
    String? token = await _firebaseMessaging.getToken();
    Map<String, dynamic> data = {
      'token': token,
    };
    ClientProvider clientProvider = ClientProvider();
    clientProvider.update(data, idUser!);
  }


  Future<void> sendMessage(String to, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('https://us-central1-apptaxi-e641d.cloudfunctions.net/sendPushToDriver'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'x-metax-secret': 'para_enviar_notificaciones_2026_metax_user',
      },
      body: jsonEncode({
        "token": to,
        "notification": {
          "title": "Metax",
          "body": "Nueva solicitud de servicio",
        },
        // 🔥 FCM data debe ser string-string
        "data": data.map((k, v) => MapEntry(k, v.toString())),
        "ttlSeconds": 25,
      }),
    );

    if (response.statusCode == 200) {
      if (kDebugMode) print('✅ Mensaje enviado: ${response.body}');
    } else {
      if (kDebugMode) print('❌ Error ${response.statusCode}: ${response.body}');
    }
  }
}
