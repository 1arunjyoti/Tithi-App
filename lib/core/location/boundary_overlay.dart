import 'dart:convert' show json, utf8;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// The national-outline layer for the home-location map.
///
/// The bundled GeoJSON is 7.5 MB / ~318k coordinate pairs. The map package's
/// `GeoJsonLayer.asset` decoded and built all of that on the main isolate in
/// `initState`, i.e. while the picker's push transition was still animating —
/// the stutter seen when drilling in from Settings or the home hero chip.
///
/// This layer does the expensive part in a background isolate via [compute]
/// and caches the built polylines for the app's lifetime. The push never waits
/// on the decode, so the route transition stays smooth on both entry paths,
/// including repeat visits.
const String _boundaryAsset = 'assets/map_data/india_boundary.geojson';

/// One ring, flattened to `[lng, lat, lng, lat, ...]`.
///
/// Only numbers and lists cross the isolate boundary; `LatLng` objects are
/// built on the UI isolate in [_IndiaBoundaryLayerState._buildLines].
typedef BoundaryRings = List<List<double>>;

/// Decode + extract every outer and inner ring. Runs in a background isolate.
///
/// Kept top-level (not a method) so [compute] can send it, and taking raw bytes
/// so even the UTF-8 decode stays off the main isolate. Input shape is
/// deliberately validated defensively: a corrupt bundle yields no outline,
/// never an exception that would take down the picker.
BoundaryRings parseBoundaryRings(Uint8List raw) {
  final Object? decoded;
  try {
    decoded = json.decode(utf8.decode(raw));
  } on Object {
    return const <List<double>>[];
  }
  if (decoded is! Map<String, dynamic>) return const <List<double>>[];

  final features = decoded['features'];
  if (features is! List) return const <List<double>>[];

  final rings = <List<double>>[];
  for (final feature in features) {
    if (feature is! Map<String, dynamic>) continue;
    final geometry = feature['geometry'];
    if (geometry is! Map<String, dynamic>) continue;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) continue;

    switch (geometry['type']) {
      case 'Polygon':
        // [exterior, hole1, hole2, ...]
        for (final ring in coordinates) {
          _appendRing(rings, ring);
        }
      case 'MultiPolygon':
        // [[exterior, hole1, ...], [exterior, hole1, ...], ...]
        for (final polygon in coordinates) {
          if (polygon is! List) continue;
          for (final ring in polygon) {
            _appendRing(rings, ring);
          }
        }
    }
  }
  return rings;
}

void _appendRing(List<List<double>> rings, Object? ring) {
  if (ring is! List) return;
  final flat = <double>[];
  for (final point in ring) {
    if (point is! List || point.length < 2) continue;
    final lng = point[0];
    final lat = point[1];
    // json.decode yields `int` for whole numbers; keep both numeric types.
    if (lng is! num || lat is! num) continue;
    flat.add(lng.toDouble());
    flat.add(lat.toDouble());
  }
  // A closed ring needs at least three points (six coordinates).
  if (flat.length >= 6) rings.add(flat);
}

/// Built once and reused across every open of the picker. The 757 polylines
/// hold ~318k `LatLng` objects, so rebuilding them on each push would itself
/// stutter the transition on every subsequent visit.
Future<List<Polyline>>? _linesFuture;

class IndiaBoundaryLayer extends StatefulWidget {
  const IndiaBoundaryLayer({super.key});

  @override
  State<IndiaBoundaryLayer> createState() => _IndiaBoundaryLayerState();
}

class _IndiaBoundaryLayerState extends State<IndiaBoundaryLayer> {
  List<Polyline>? _lines;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Single-flight: two quick opens share one decode/build instead of racing.
    final lines = await (_linesFuture ??= _buildLinesOnce());
    if (!mounted) return;
    setState(() => _lines = lines);
  }

  static Future<List<Polyline>> _buildLinesOnce() async {
    return _buildLines(await _readAndParse());
  }

  static Future<BoundaryRings> _readAndParse() async {
    try {
      // `load` is async on the platform channel; handing the bytes to a worker
      // isolate keeps the UTF-8 + JSON decode off the UI isolate entirely.
      final data = await rootBundle.load(_boundaryAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return await compute(parseBoundaryRings, bytes);
    } on Object {
      // A missing/corrupt bundle simply leaves the map without an outline;
      // it must never take the picker (or the push transition) down.
      return const <List<double>>[];
    }
  }

  /// Expands the flat pairs back into `LatLng`s and matches the old visual:
  /// a 1.5 px orange outline, no fill.
  static List<Polyline> _buildLines(BoundaryRings rings) {
    return [
      for (final ring in rings)
        Polyline(
          points: [
            for (var i = 0; i < ring.length; i += 2)
              LatLng(ring[i + 1], ring[i]),
          ],
          color: AppTheme.mapBoundary,
          strokeWidth: 1.5,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    if (lines == null || lines.isEmpty) return const SizedBox.shrink();
    return PolylineLayer(polylines: lines);
  }
}
