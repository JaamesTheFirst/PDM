/// Decodes a Google-encoded polyline string into a list of [lat, lon] coordinate pairs.
List<List<double>> decodePolyline(String encoded) {
  final List<List<double>> coordinates = [];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int result = 0;
    int shift = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += deltaLat;

    result = 0;
    shift = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += deltaLng;

    coordinates.add([lat / 1e5, lng / 1e5]); // [lat, lon]
  }

  return coordinates;
}