class Temple {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double? distance; // Distance from user in meters

  const Temple({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.distance,
  });

  factory Temple.fromJson(Map<String, dynamic> json) {
    // Overpass API returns "lat" and "lon" for nodes.
    // Tags contain metadata like name.
    final tags = json['tags'] as Map<String, dynamic>? ?? {};
    // SEC-2: Clamp coordinates to valid geographic ranges so malformed API
    // responses don't propagate invalid values into map widgets.
    final lat = (json['lat'] as double? ?? 0.0).clamp(-90.0, 90.0);
    final lon = (json['lon'] as double? ?? 0.0).clamp(-180.0, 180.0);

    // Sometimes name is multilingual, try to find a sensible default
    String name = tags['name'] ?? tags['name:en'] ?? 'Unknown Temple';

    return Temple(
      id: json['id'] as int? ?? 0,
      name: name,
      latitude: lat,
      longitude: lon,
    );
  }
}
