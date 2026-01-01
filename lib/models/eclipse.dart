/// Eclipse type enumeration
enum EclipseType {
  /// Total solar eclipse
  solarTotal,

  /// Annular solar eclipse (ring of fire)
  solarAnnular,

  /// Partial solar eclipse
  solarPartial,

  /// Hybrid (annular-total) solar eclipse
  solarHybrid,

  /// Total lunar eclipse
  lunarTotal,

  /// Partial lunar eclipse
  lunarPartial,

  /// Penumbral lunar eclipse
  lunarPenumbral,
}

/// Extension for eclipse type display
extension EclipseTypeExtension on EclipseType {
  String get displayName {
    switch (this) {
      case EclipseType.solarTotal:
        return 'Total Solar Eclipse';
      case EclipseType.solarAnnular:
        return 'Annular Solar Eclipse';
      case EclipseType.solarPartial:
        return 'Partial Solar Eclipse';
      case EclipseType.solarHybrid:
        return 'Hybrid Solar Eclipse';
      case EclipseType.lunarTotal:
        return 'Total Lunar Eclipse';
      case EclipseType.lunarPartial:
        return 'Partial Lunar Eclipse';
      case EclipseType.lunarPenumbral:
        return 'Penumbral Lunar Eclipse';
    }
  }

  String get displayNameHi {
    switch (this) {
      case EclipseType.solarTotal:
        return 'पूर्ण सूर्य ग्रहण';
      case EclipseType.solarAnnular:
        return 'वलयाकार सूर्य ग्रहण';
      case EclipseType.solarPartial:
        return 'आंशिक सूर्य ग्रहण';
      case EclipseType.solarHybrid:
        return 'मिश्र सूर्य ग्रहण';
      case EclipseType.lunarTotal:
        return 'पूर्ण चंद्र ग्रहण';
      case EclipseType.lunarPartial:
        return 'आंशिक चंद्र ग्रहण';
      case EclipseType.lunarPenumbral:
        return 'उपच्छाया चंद्र ग्रहण';
    }
  }

  bool get isSolar => name.startsWith('solar');
  bool get isLunar => name.startsWith('lunar');

  String get icon => isSolar ? '☀️' : '🌙';
}

/// Data class representing an eclipse event
class Eclipse {
  const Eclipse({
    required this.type,
    required this.maxEclipseTime,
    this.partialStart,
    this.partialEnd,
    this.totalStart,
    this.totalEnd,
    this.penumbralStart,
    this.penumbralEnd,
    this.magnitude,
    this.centerLatitude,
    this.centerLongitude,
    this.visibleAtLocation = false,
    this.localMagnitude,
    this.localAltitude,
  });

  /// Type of eclipse
  final EclipseType type;

  /// Time of maximum eclipse (UTC)
  final DateTime maxEclipseTime;

  /// When partial phase begins
  final DateTime? partialStart;

  /// When partial phase ends
  final DateTime? partialEnd;

  /// When total/annular phase begins (if applicable)
  final DateTime? totalStart;

  /// When total/annular phase ends (if applicable)
  final DateTime? totalEnd;

  /// When penumbral phase begins (lunar eclipse only)
  final DateTime? penumbralStart;

  /// When penumbral phase ends (lunar eclipse only)
  final DateTime? penumbralEnd;

  /// Eclipse magnitude (0.0 - 1.0+)
  final double? magnitude;

  /// Latitude of eclipse center (for solar eclipses)
  final double? centerLatitude;

  /// Longitude of eclipse center (for solar eclipses)
  final double? centerLongitude;

  /// Whether eclipse is visible at user's location
  final bool visibleAtLocation;

  /// Magnitude as seen from observer's location
  final double? localMagnitude;

  /// Sun/Moon altitude at maximum eclipse for observer
  final double? localAltitude;

  /// Total duration of the event
  Duration? get totalDuration {
    if (type.isLunar && penumbralStart != null && penumbralEnd != null) {
      return penumbralEnd!.difference(penumbralStart!);
    }
    if (partialStart != null && partialEnd != null) {
      return partialEnd!.difference(partialStart!);
    }
    return null;
  }

  /// Duration of totality/annularity
  Duration? get totalityDuration {
    if (totalStart != null && totalEnd != null) {
      return totalEnd!.difference(totalStart!);
    }
    return null;
  }

  /// Days until this eclipse
  int get daysUntil {
    final now = DateTime.now();
    return maxEclipseTime.difference(now).inDays;
  }

  /// Create a copy with updated visibility info
  Eclipse copyWithVisibility({
    bool? visibleAtLocation,
    double? localMagnitude,
    double? localAltitude,
  }) {
    return Eclipse(
      type: type,
      maxEclipseTime: maxEclipseTime,
      partialStart: partialStart,
      partialEnd: partialEnd,
      totalStart: totalStart,
      totalEnd: totalEnd,
      penumbralStart: penumbralStart,
      penumbralEnd: penumbralEnd,
      magnitude: magnitude,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      visibleAtLocation: visibleAtLocation ?? this.visibleAtLocation,
      localMagnitude: localMagnitude ?? this.localMagnitude,
      localAltitude: localAltitude ?? this.localAltitude,
    );
  }

  @override
  String toString() {
    return 'Eclipse(${type.displayName}, $maxEclipseTime, mag: $magnitude)';
  }
}
