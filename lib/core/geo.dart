import 'dart:math' as math;

/// Mean Earth radius (IUGG), km.
const double earthRadiusKm = 6371.0088;

/// Great-circle ("kuş uçuşu") distance in km between two coordinates in
/// degrees, on a spherical Earth (haversine). Within ~0.5% of the
/// ellipsoidal distance, well inside any sensible guess interval.
double greatCircleKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
}
