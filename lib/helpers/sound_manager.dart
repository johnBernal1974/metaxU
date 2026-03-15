import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class SoundManager {

  static final SoundManager _instance = SoundManager._internal();

  factory SoundManager() {
    return _instance;
  }

  SoundManager._internal();

  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;

  Future<void> playTaxiLlegada() async {
    await _play("assets/audio/tu_taxi_ha_llegado.mp3");
  }

  Future<void> playCancelacionConductor() async {
    await _play("assets/audio/el_conductor_cancelo_el_servicio.wav");
  }

  Future<void> _play(String asset) async {

    try {

      if (_isPlaying) {
        await _player.stop();
      }

      _isPlaying = true;

      await _player.setAsset(asset);
      await _player.play();

      _player.playerStateStream.listen((state) {

        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
        }

      });

    } catch (e) {
      debugPrint("Error reproduciendo sonido: $e");
    }

  }

}