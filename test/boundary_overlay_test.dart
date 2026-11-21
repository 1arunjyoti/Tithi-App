import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/core/location/boundary_overlay.dart';

/// The picker used to decode a 7.5 MB GeoJSON with ~318k coordinate pairs on
/// the main isolate the moment it opened, stuttering the push transition from
/// both Settings and the home hero's location chip. [parseBoundaryRings] is
/// the off-isolate half of that work; these tests lock its geometry contract.
void main() {
  Uint8List bytesOf(String source) => Uint8List.fromList(utf8.encode(source));

  test('extracts every MultiPolygon ring as flat [lng, lat, ...] pairs', () {
    const source = '''
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {"name": "India"},
          "geometry": {
            "type": "MultiPolygon",
            "coordinates": [
              [
                [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0], [1.0, 2.0]],
                [[1.5, 2.5], [1.6, 2.6], [1.7, 2.7], [1.5, 2.5]]
              ],
              [
                [[10.0, 20.0], [11.0, 21.0], [12.0, 22.0], [10.0, 20.0]]
              ]
            ]
          }
        }
      ]
    }
    ''';

    final rings = parseBoundaryRings(bytesOf(source));

    expect(rings, hasLength(3));
    expect(rings[0], [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 1.0, 2.0]);
    expect(rings[1], [1.5, 2.5, 1.6, 2.6, 1.7, 2.7, 1.5, 2.5]);
    expect(rings[2], [10.0, 20.0, 11.0, 21.0, 12.0, 22.0, 10.0, 20.0]);
  });

  test('also handles a plain Polygon feature', () {
    const source = '''
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 0.0]]
            ]
          }
        }
      ]
    }
    ''';

    expect(parseBoundaryRings(bytesOf(source)), [
      [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0],
    ]);
  });

  test('drops degenerate rings and malformed coordinates without throwing', () {
    const source = '''
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "type": "MultiPolygon",
            "coordinates": [
              [
                [[1.0, 2.0]],
                [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0], [1.0, 2.0]],
                [[null, 2.0], ["bad", 4.0], [5.0, 6.0]]
              ]
            ]
          }
        }
      ]
    }
    ''';

    expect(parseBoundaryRings(bytesOf(source)), [
      [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 1.0, 2.0],
    ]);
  });

  test('returns no rings for an empty or non-FeatureCollection payload', () {
    expect(
      parseBoundaryRings(bytesOf('{"type":"FeatureCollection","features":[]}')),
      isEmpty,
    );
    expect(parseBoundaryRings(bytesOf('{"type":"Point","coordinates":[1,2]}')),
        isEmpty);
  });

  test('parses the bundled India boundary into a usable outline', () {
    // Real-data shape guard: if the shipped asset ever changes nesting or
    // coordinate encoding, the picker would silently lose its outline.
    final file = File('assets/map_data/india_boundary.geojson');
    final rings = parseBoundaryRings(file.readAsBytesSync());

    expect(rings, hasLength(greaterThan(100)));
    // 756 islands/rings, ~318k points in the shipped file.
    expect(
      rings.fold<int>(0, (sum, ring) => sum + ring.length),
      greaterThan(100000),
    );
    expect(rings.every((ring) => ring.length >= 6 && ring.length.isEven), isTrue);
  });
}
