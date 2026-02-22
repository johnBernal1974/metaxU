import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'device_session.dart';

class SessionManager {
  static const _uuid = Uuid();

  /// Tiempo máximo sin latido para considerar sesión muerta (ajústalo)
  static const int sessionTimeoutSeconds = 60; // 1 min

  static Timer? _heartbeatTimer;

  static Future<void> loginGuard({
    required String collection, // 'Drivers' o 'Clients'
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final uid = user.uid;
    final deviceId = await DeviceSession.getOrCreateDeviceId();
    final sessionId = _uuid.v4();

    final ref = FirebaseFirestore.instance.collection(collection).doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);

      // ✅ CLAVE: si NO existe el documento del perfil, NO lo crees aquí.
      // Esto evita que se creen documentos “fantasma” con isLoggedIn/deviceId...
      if (!snap.exists) {
        throw Exception('PROFILE_NOT_FOUND');
      }

      final data = (snap.data() ?? {});

      final bool isLoggedIn = (data['isLoggedIn'] == true);
      final String storedDeviceId = (data['deviceId'] ?? '').toString();
      final Timestamp? lastSeenTs = data['lastSeen'] as Timestamp?;

      final now = DateTime.now();
      final lastSeen = lastSeenTs?.toDate();

      final bool isSameDevice =
          storedDeviceId.isNotEmpty && storedDeviceId == deviceId;

      final bool sessionExpired = (lastSeen == null)
          ? true
          : now.difference(lastSeen).inSeconds > sessionTimeoutSeconds;

      // ❌ Caso 4: otra instalación y sesión viva → bloquea
      if (isLoggedIn && !isSameDevice && !sessionExpired) {
        throw Exception('Ya hay una sesión activa en otro dispositivo');
      }

      // ✅ Como el doc existe, usamos UPDATE (no set merge)
      tx.update(ref, {
        'isLoggedIn': true,
        'deviceId': deviceId,
        'sessionId': sessionId,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    });
  }

  /// “Latido” para mantener la sesión viva (llámalo cada 30-60s)
  static Future<void> heartbeat({
    required String collection,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final deviceId = await DeviceSession.getOrCreateDeviceId();

    final ref = FirebaseFirestore.instance.collection(collection).doc(uid);

    // Solo actualiza si el deviceId coincide (para no pisar a otro)
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final storedDeviceId = (data['deviceId'] ?? '').toString();

      if (storedDeviceId != deviceId) return;

      tx.update(ref, {
        'lastSeen': FieldValue.serverTimestamp(),
      });
    });
  }

  /// ✅ NUEVO: inicia el latido automático
  static void startHeartbeat({
    required String collection,
    int everySeconds = 45, // recomendado 30-60
  }) {
    stopHeartbeat(); // evita duplicados

    _heartbeatTimer = Timer.periodic(Duration(seconds: everySeconds), (_) async {
      try {
        await heartbeat(collection: collection);
      } catch (_) {}
    });
  }

  /// ✅ NUEVO: detiene el latido
  static void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static Future<void> logout({
    required String collection,
  }) async {
    stopHeartbeat();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final deviceId = await DeviceSession.getOrCreateDeviceId();

    final ref = FirebaseFirestore.instance.collection(collection).doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final storedDeviceId = (data['deviceId'] ?? '').toString();

      // 🔒 Solo cierra sesión si es el mismo dispositivo
      if (storedDeviceId != deviceId) return;

      tx.update(ref, {
        'isLoggedIn': false,
        'deviceId': '',
        'sessionId': '',
        'lastSeen': null, // ✅ AQUÍ VA
      });
    });
  }

}
