import 'dart:convert';

import '../core/strings.dart';

/// A city with sourced coordinates, from assets/data/places.json.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.country,
  });

  /// Wikidata QID, e.g. `Q3640` (Ankara).
  final String id;
  final String name;
  final double lat;
  final double lon;

  /// Set for world capitals.
  final String? country;

  /// `Prag (Çekya)`; just the name when it equals the country (Singapur).
  String get displayName => country == null || country == name
      ? name
      : AppStrings.placeWithCountry(name, country!);

  String get source => 'https://www.wikidata.org/wiki/$id';

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    id: json['id'] as String,
    name: json['name'] as String,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    country: json['country'] as String?,
  );
}

class PlaceData {
  const PlaceData({
    required this.dataYear,
    required this.turkey,
    required this.world,
  });

  final int dataYear;

  /// Province capitals of Turkey.
  final List<Place> turkey;

  /// Capitals of well-known countries.
  final List<Place> world;

  /// Throws [FormatException] or [TypeError] on invalid data.
  factory PlaceData.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    List<Place> places(String key) => List.unmodifiable([
      for (final item in json[key] as List)
        Place.fromJson(item as Map<String, dynamic>),
    ]);
    return PlaceData(
      dataYear: json['data_year'] as int,
      turkey: places('tr'),
      world: places('world'),
    );
  }
}
