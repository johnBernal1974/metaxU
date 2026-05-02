import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class SoundManager {

  static final SoundManager _instance = SoundManager._internal();

  factory SoundManager() {
    return _instance;
  }

  SoundManager._internal();

  final AudioPlayer _player = AudioPlayer();

  String? _lastSound;
  DateTime? _lastTime;

  Future<void> playTaxiLlegada() async {
    await _play("assets/audio/tu_taxi_ha_llegado.mp3");
  }

  Future<void> playCancelacionConductor() async {
    await _play("assets/audio/el_conductor_cancelo_el_servicio.wav");
  }

  Future<void> playServicioAceptado() async {
    await _play("assets/audio/servicio_aceptado_new.mp3");
  }

  Future<void> _play(String asset) async {
    try {

      final now = DateTime.now();

      // 🔒 evita eco por eventos repetidos del stream
      if (_lastSound == asset &&
          _lastTime != null &&
          now.difference(_lastTime!) < const Duration(milliseconds: 800)) {
        return;
      }

      _lastSound = asset;
      _lastTime = now;

      // 🔥 SIEMPRE detener antes
      await _player.stop();

      await _player.setAsset(asset);
      await _player.setVolume(1.0);
      await _player.play();

    } catch (e) {
      debugPrint("Error reproduciendo sonido: $e");
    }
  }

}