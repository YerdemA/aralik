import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One data source the bank uses, with the credit its license asks for.
/// Generated from tools/sources.json by tools/build_attributions.py.
@immutable
class Attribution {
  const Attribution({
    required this.name,
    required this.attribution,
    required this.license,
    required this.licenseUrl,
    required this.url,
  });

  final String name;
  final String attribution;
  final String license;
  final String licenseUrl;
  final String url;

  factory Attribution.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw FormatException('attribution must be an object: $json');
    }
    String field(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
      throw FormatException('attribution needs "$key": $json');
    }

    return Attribution(
      name: field('name'),
      attribution: field('attribution'),
      license: field('license'),
      licenseUrl: field('license_url'),
      url: field('url'),
    );
  }
}

const attributionsAssetPath = 'assets/data/attributions.json';

/// Parses attributions.json. Throws [FormatException] on invalid data.
List<Attribution> parseAttributions(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw const FormatException('attributions.json must be a list');
  }
  return List.unmodifiable(decoded.map(Attribution.fromJson));
}

Future<List<Attribution>> loadAttributions([AssetBundle? bundle]) async =>
    parseAttributions(
      await (bundle ?? rootBundle).loadString(attributionsAssetPath),
    );
