import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerUtils {
  // Ahora pedimos el pixelRatio en lugar del context
  static Future<BitmapDescriptor> getMarkerFromAsset(String path, double pixelRatio, double baseSize) async {
    try {
      int finalWidth = (baseSize * pixelRatio).round();
      ByteData data = await rootBundle.load(path);
      ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: finalWidth,
      );
      ui.FrameInfo fi = await codec.getNextFrame();
      ByteData? markerBuffer = await fi.image.toByteData(format: ui.ImageByteFormat.png);

      if (markerBuffer == null) return BitmapDescriptor.defaultMarker; // Fallback

      return BitmapDescriptor.fromBytes(markerBuffer.buffer.asUint8List());
    } catch (e) {
      debugPrint("⚠️ Error cargando marcador: $e");
      return BitmapDescriptor.defaultMarker; // Retorna marcador estándar si falla
    }
  }
}