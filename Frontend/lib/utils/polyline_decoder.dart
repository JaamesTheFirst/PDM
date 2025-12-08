/// Utilitário para decodificar polylines no formato Google.
///
/// Este formato é usado por vários serviços de mapas (incluindo OTP/Mapbox)
/// para representar uma sequência de coordenadas de forma compacta.
///
/// Retorna uma lista de pares `[lat, lon]` em graus decimais.
///
/// Mais detalhes sobre o formato:
/// - "Encoded Polyline Algorithm Format" (Google).
/// - Cada ponto é codificado como delta em relação ao anterior.
List<List<double>> decodePolyline(String encoded) {
  final List<List<double>> coordinates = [];
  int index = 0;
  int lat = 0;
  int lng = 0;

  // Enquanto houver caracteres na string codificada,
  // vamos extraindo delta de latitude e longitude.
  while (index < encoded.length) {
    int result = 0;
    int shift = 0;
    int b;

    // --- Decodificar latitude ---
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += deltaLat;

    // --- Decodificar longitude ---
    result = 0;
    shift = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += deltaLng;

    // Converter de inteiros escalados para graus decimais.
    coordinates.add([lat / 1e5, lng / 1e5]); // [lat, lon]
  }

  return coordinates;
}
