import 'package:flutter/foundation.dart';
import 'package:jyotish/jyotish.dart';

import 'hindu_month_system.dart';
import 'panchang_school.dart';

/// Settings-box key for the persisted [PanchangProfile] JSON map.
///
/// The value is a `Map<String, dynamic>` produced by [PanchangProfile.toJson],
/// not an enum index. Storing the map keeps the profile readable and lets new
/// fields land with defaults instead of remapping old indices.
const String kPanchangProfilePrefKey = 'panchang_profile';

/// Monotonic version of the calculation contract described by
/// [PanchangProfile].
///
/// Bump this whenever a profile change can move a Panchang output: school,
/// ayanamsa, sunrise/sunset convention, Moon limb/refraction policy, checkpoint
/// policy, node convention, or a new regional rule set. Cached Panchang and
/// festival records must key on it and be discarded when it changes. Never
/// reuse a version number once it has shipped.
///
/// 4: the calculation school (Bisuddhasiddhanta / Suryasiddhanta) became
/// selectable, so a day cached under one school must not be served for the
/// other.
const int kPanchangCalculationVersion = 4;

/// Sentinel used by [PanchangProfile.copyWith] to distinguish "leave as is"
/// from "set to null" for nullable fields.
const Object _unset = Object();

/// Solar rise/set convention used to assemble a Panchang day.
enum SolarEventConvention {
  /// Swiss Ephemeris `SE_BIT_HINDU_RISING`: disc centre, no refraction,
  /// geocentric. This is Tithi's target default.
  hindu,

  /// Apparent upper-limb rise/set with standard refraction (the current
  /// NOAA-style calculator). Kept as a labelled fallback where the native
  /// binding is unavailable; never present it as the Hindu convention.
  apparentUpperLimb,
}

/// Lunar limb policy for Moon rise/set. Separate from [SolarEventConvention]:
/// the Hindu solar bit ignores ecliptic latitude and is wrong for the Moon.
enum LunarLimb {
  /// Upper limb tangent (traditional visible moonrise).
  upperLimb,

  /// Disc centre.
  center,

  /// Lower limb tangent.
  lowerLimb,
}

/// Refraction policy for Moon rise/set.
enum LunarRefraction {
  /// Geometric event, no atmospheric refraction.
  none,

  /// Standard atmospheric refraction.
  standard,
}

/// Intraday instant at which a festival rule may be evaluated.
///
/// The `.name` values are the identifiers already used by
/// `PanchangRules.timingOverride` and `PanchangRules.pujaKala`, so the profile
/// and the shipped festival data cannot drift on spelling.
enum ObservanceCheckpoint {
  brahmaMuhurtaStart,
  arunodaya,
  purvahna,
  sayahnaStart,
  sayahnaCenter,
  sayahnaEnd,
  sunrise,
  madhyahna,
  aparahna,
  nishita,
  pradosha,
  moonrise,
}

/// How a Kshaya (skipped) tithi is handled when matching a festival.
enum KshayaPolicy {
  /// Fall back to the day the skipped tithi is squeezed into. Current shipped
  /// behaviour.
  fallback,

  /// Do not match a festival when its tithi is skipped.
  strict,
}

/// Which day of a Vriddhi (two-sunrise) tithi a festival is observed on.
enum VriddhiPolicy {
  /// First sunrise of the run.
  first,

  /// Last sunrise of the run.
  second,

  /// Every matching sunrise. Current shipped default (`PanchangRules.vriddhi`
  /// defaults to `'both'`).
  both,
}

/// How the dominant tithi is sampled around sunrise.
enum DominantTithiPolicy {
  /// Sample a grace window after sunrise for festivals whose tithi begins
  /// shortly after sunrise. Current shipped behaviour, except rules that set
  /// `PanchangRules.dominantTithi = 'strict'` (the Durga Puja days).
  grace,

  /// Match only the exact sunrise tithi.
  strict,
}

/// Lunar node convention for any node-dependent calculation.
///
/// `true` is a Dart keyword, hence the `Node` suffix on both values.
enum NodeConvention { meanNode, trueNode }

/// Which instant of the Nishita Kaal window decides a `nishita` observance.
///
/// Nishita Kaal is not a point: it is the eighth of the fifteen night muhurtas,
/// a window of `night / 15` centred on the night midpoint
/// (`sunset + 7/15 night` to `sunset + 8/15 night`).
enum NishitaPolicy {
  /// The window opening decides. A tithi that only arrives before the window
  /// closes still counts, so a required tithi never loses a day because it
  /// began a few minutes after the window opened. Shipped default.
  windowEdges,

  /// The night midpoint decides (the pre-`panchang-v3` point sample).
  ///
  /// Kept only to reproduce older results; it misses observances whose tithi
  /// ends between the window opening and the midpoint (the Janmashtami
  /// defect: Delhi and Mumbai 2026-09-04).
  midpoint,
}

/// What a `moonrise` observance does when the Moon does not rise on the civil
/// day.
///
/// The Moon skips a rise on roughly one civil day a month (its rise drifts
/// ~50 minutes later each day), and stays below the horizon all day at high
/// latitudes. The day still needs an answer.
enum MoonrisePolicy {
  /// Use the day's own tithi - the sunrise sample, or civil noon when there is
  /// no sunrise. Shipped default: a day without a moonrise keeps the result it
  /// had before the checkpoint existed, instead of dropping the observance.
  fallbackToSunrise,

  /// A day without a moonrise cannot satisfy a `moonrise` rule, so the
  /// observance moves to a day whose Moon does rise.
  requireRise,
}

/// Festival-observance policy shared by a [PanchangProfile]. Defaults reproduce
/// shipped conventions, so adoption alone changes nothing; Phase 2 wires this
/// into the matcher and scheduler, replacing `timingOverrideCheckpoints`.
class FestivalObservancePolicy {
  const FestivalObservancePolicy({
    this.checkpoints = const {
      ObservanceCheckpoint.brahmaMuhurtaStart,
      ObservanceCheckpoint.arunodaya,
      ObservanceCheckpoint.purvahna,
      ObservanceCheckpoint.sayahnaStart,
      ObservanceCheckpoint.sayahnaCenter,
      ObservanceCheckpoint.sayahnaEnd,
      ObservanceCheckpoint.sunrise,
      ObservanceCheckpoint.madhyahna,
      ObservanceCheckpoint.aparahna,
      ObservanceCheckpoint.nishita,
      ObservanceCheckpoint.pradosha,
      ObservanceCheckpoint.moonrise,
    },
    this.kshaya = KshayaPolicy.fallback,
    this.vriddhi = VriddhiPolicy.both,
    this.dominantTithi = DominantTithiPolicy.grace,
    this.nishita = NishitaPolicy.windowEdges,
    this.moonrise = MoonrisePolicy.fallbackToSunrise,
  });

  /// Target policy: every documented checkpoint, including moonrise.
  ///
  /// `moonrise` is a matching checkpoint: a festival rule may set
  /// `timingOverride: moonrise` and is then tested against the tithi at the
  /// Moon's rise instead of at sunrise.
  static const FestivalObservancePolicy standard = FestivalObservancePolicy();

  /// Checkpoints the matcher may evaluate.
  final Set<ObservanceCheckpoint> checkpoints;

  /// Kshaya handling.
  final KshayaPolicy kshaya;

  /// Vriddhi handling.
  final VriddhiPolicy vriddhi;

  /// Dominant-tithi handling.
  final DominantTithiPolicy dominantTithi;

  /// Which instant of the Nishita window decides a `nishita` observance.
  final NishitaPolicy nishita;

  /// What a `moonrise` observance does when the Moon does not rise that day.
  final MoonrisePolicy moonrise;

  FestivalObservancePolicy copyWith({
    Set<ObservanceCheckpoint>? checkpoints,
    KshayaPolicy? kshaya,
    VriddhiPolicy? vriddhi,
    DominantTithiPolicy? dominantTithi,
    NishitaPolicy? nishita,
    MoonrisePolicy? moonrise,
  }) {
    return FestivalObservancePolicy(
      checkpoints: checkpoints ?? this.checkpoints,
      kshaya: kshaya ?? this.kshaya,
      vriddhi: vriddhi ?? this.vriddhi,
      dominantTithi: dominantTithi ?? this.dominantTithi,
      nishita: nishita ?? this.nishita,
      moonrise: moonrise ?? this.moonrise,
    );
  }

  /// Deterministic JSON: checkpoint names are sorted so two equal policies
  /// always serialize identically.
  Map<String, dynamic> toJson() {
    final names = checkpoints.map((checkpoint) => checkpoint.name).toList()
      ..sort();
    return {
      'checkpoints': names,
      'kshaya': kshaya.name,
      'vriddhi': vriddhi.name,
      'dominantTithi': dominantTithi.name,
      'nishita': nishita.name,
      'moonrise': moonrise.name,
    };
  }

  /// Tolerant parse: unknown names and missing keys fall back to [standard].
  factory FestivalObservancePolicy.fromJson(Map<String, dynamic>? json) {
    if (json == null) return standard;

    final rawCheckpoints = json['checkpoints'];
    final parsedCheckpoints = rawCheckpoints is List
        ? rawCheckpoints
              .whereType<String>()
              .map(_checkpointByName)
              .whereType<ObservanceCheckpoint>()
              .toSet()
        : <ObservanceCheckpoint>{};

    return FestivalObservancePolicy(
      checkpoints: parsedCheckpoints.isEmpty
          ? standard.checkpoints
          : parsedCheckpoints,
      kshaya: _enumByName(
        KshayaPolicy.values,
        json['kshaya'],
        KshayaPolicy.fallback,
      ),
      vriddhi: _enumByName(
        VriddhiPolicy.values,
        json['vriddhi'],
        VriddhiPolicy.both,
      ),
      dominantTithi: _enumByName(
        DominantTithiPolicy.values,
        json['dominantTithi'],
        DominantTithiPolicy.grace,
      ),
      nishita: _enumByName(
        NishitaPolicy.values,
        json['nishita'],
        NishitaPolicy.windowEdges,
      ),
      moonrise: _enumByName(
        MoonrisePolicy.values,
        json['moonrise'],
        MoonrisePolicy.fallbackToSunrise,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FestivalObservancePolicy &&
        setEquals(other.checkpoints, checkpoints) &&
        other.kshaya == kshaya &&
        other.vriddhi == vriddhi &&
        other.dominantTithi == dominantTithi &&
        other.nishita == nishita &&
        other.moonrise == moonrise;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(checkpoints),
    kshaya,
    vriddhi,
    dominantTithi,
    nishita,
    moonrise,
  );

  @override
  String toString() =>
      'FestivalObservancePolicy(checkpoints: $checkpoints, '
      'kshaya: ${kshaya.name}, vriddhi: ${vriddhi.name}, '
      'dominantTithi: ${dominantTithi.name}, nishita: ${nishita.name}, '
      'moonrise: ${moonrise.name})';
}

/// Versioned calculation contract for the Panchang.
///
/// This is domain configuration, not a display preference. In particular
/// `FestivalRegion` must not be reused here: that enum only orders festivals
/// on a shared day.
///
/// The profile is the Phase 0 contract. Nothing reads it yet; the solar-events
/// seam continues to delegate to the existing calculator until Phase 1b swaps
/// the implementation. `PanchangProfile.standard` describes the target engine,
/// not necessarily what currently runs.
class PanchangProfile {
  const PanchangProfile({
    this.school = PanchangSchool.bisuddha,
    this.ayanamsa = SiderealMode.lahiri,
    this.monthSystem = HinduMonthSystem.amanta,
    this.solarConvention = SolarEventConvention.hindu,
    this.lunarLimb = LunarLimb.upperLimb,
    this.lunarRefraction = LunarRefraction.standard,
    this.timezoneId,
    this.observance = FestivalObservancePolicy.standard,
    this.nodeConvention = NodeConvention.meanNode,
    this.regionalRuleSetId,
    this.calculationVersion = kPanchangCalculationVersion,
  });

  /// Target profile: Bisuddhasiddhanta, Lahiri, Amanta, Hindu sunrise,
  /// traditional moonrise.
  static const PanchangProfile standard = PanchangProfile();

  /// Serialization schema for [toJson]. Bump only when the JSON shape changes;
  /// this is separate from [calculationVersion], which tracks semantics.
  static const int schemaVersion = 2;

  /// Calculation school: which planetary theory produces every longitude.
  ///
  /// This is the outermost switch in the contract. [ayanamsa] only applies to
  /// [PanchangSchool.bisuddha]; the Surya Siddhanta engine is sidereal by
  /// construction and ignores it.
  final PanchangSchool school;

  /// Ayanamsa (sidereal zodiac) used for every longitude in the profile.
  final SiderealMode ayanamsa;

  /// Civil month system used when naming masa.
  final HinduMonthSystem monthSystem;

  /// Sun rise/set convention.
  final SolarEventConvention solarConvention;

  /// Moon limb policy for rise/set.
  final LunarLimb lunarLimb;

  /// Moon refraction policy for rise/set.
  final LunarRefraction lunarRefraction;

  /// Effective IANA zone for civil time.
  ///
  /// Seeded from the selected place ([LocationData] once Phase 0 adds the
  /// field) and kept here so a cached Panchang record is self-describing.
  /// `null` means "resolve from the place, then the device zone".
  final String? timezoneId;

  /// Festival-observance policy.
  final FestivalObservancePolicy observance;

  /// Lunar node convention.
  final NodeConvention nodeConvention;

  /// Opaque identifier for a regional rule set owned by the observance
  /// engine. `null` is the pan-India default.
  ///
  /// Not a [FestivalRegion]: that enum is display ordering only.
  final String? regionalRuleSetId;

  /// Calculation-engine version; see [kPanchangCalculationVersion].
  final int calculationVersion;

  /// Stable tag for cache keys and provenance records.
  String get engineTag => 'panchang-v$calculationVersion';

  /// Deterministic cache key covering every field that can change an output.
  ///
  /// Include this in Panchang/Hive cache keys so a profile edit cannot serve a
  /// record calculated under a different contract.
  String get cacheKey {
    final checkpoints =
        observance.checkpoints.map((checkpoint) => checkpoint.name).toList()
          ..sort();
    return <String>[
      engineTag,
      'school:${school.name}',
      'ayanamsa:${ayanamsa.constant}',
      'months:${monthSystem.name}',
      'solar:${solarConvention.name}',
      'moon:${lunarLimb.name}/${lunarRefraction.name}',
      'tz:${timezoneId ?? '-'}',
      'checkpoints:${checkpoints.join(',')}',
      'kshaya:${observance.kshaya.name}',
      'vriddhi:${observance.vriddhi.name}',
      'dominant:${observance.dominantTithi.name}',
      'nishita:${observance.nishita.name}',
      'moonrise:${observance.moonrise.name}',
      'nodes:${nodeConvention.name}',
      'rules:${regionalRuleSetId ?? '-'}',
    ].join('|');
  }

  PanchangProfile copyWith({
    PanchangSchool? school,
    SiderealMode? ayanamsa,
    HinduMonthSystem? monthSystem,
    SolarEventConvention? solarConvention,
    LunarLimb? lunarLimb,
    LunarRefraction? lunarRefraction,
    Object? timezoneId = _unset,
    FestivalObservancePolicy? observance,
    NodeConvention? nodeConvention,
    Object? regionalRuleSetId = _unset,
    int? calculationVersion,
  }) {
    return PanchangProfile(
      school: school ?? this.school,
      ayanamsa: ayanamsa ?? this.ayanamsa,
      monthSystem: monthSystem ?? this.monthSystem,
      solarConvention: solarConvention ?? this.solarConvention,
      lunarLimb: lunarLimb ?? this.lunarLimb,
      lunarRefraction: lunarRefraction ?? this.lunarRefraction,
      timezoneId: identical(timezoneId, _unset)
          ? this.timezoneId
          : timezoneId as String?,
      observance: observance ?? this.observance,
      nodeConvention: nodeConvention ?? this.nodeConvention,
      regionalRuleSetId: identical(regionalRuleSetId, _unset)
          ? this.regionalRuleSetId
          : regionalRuleSetId as String?,
      calculationVersion: calculationVersion ?? this.calculationVersion,
    );
  }

  /// Deterministic JSON map suitable for the settings box.
  ///
  /// The ayanamsa is stored as the Swiss Ephemeris sidereal-mode integer, not
  /// an enum index or label, so reordering [SiderealMode] cannot remap a
  /// stored profile.
  Map<String, dynamic> toJson() => {
    'schema': schemaVersion,
    'calculationVersion': calculationVersion,
    'school': school.name,
    'ayanamsa': ayanamsa.constant,
    'monthSystem': monthSystem.name,
    'solarConvention': solarConvention.name,
    'lunarLimb': lunarLimb.name,
    'lunarRefraction': lunarRefraction.name,
    'timezoneId': timezoneId,
    'observance': observance.toJson(),
    'nodeConvention': nodeConvention.name,
    'regionalRuleSetId': regionalRuleSetId,
  };

  /// Tolerant parse of a stored profile.
  ///
  /// Missing keys, unknown identifiers and non-map input all fall back to
  /// [standard], so an empty or older settings box upgrades cleanly. A map
  /// written by a newer schema is rejected rather than misinterpreted.
  factory PanchangProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return standard;

    final schema = json['schema'];
    if (schema is int && schema > schemaVersion) {
      return standard;
    }

    final rawObservance = json['observance'];

    return PanchangProfile(
      school: panchangSchoolFromName(json['school']),
      ayanamsa: _siderealModeFromConstant(json['ayanamsa']),
      monthSystem: _enumByName(
        HinduMonthSystem.values,
        json['monthSystem'],
        HinduMonthSystem.amanta,
      ),
      solarConvention: _enumByName(
        SolarEventConvention.values,
        json['solarConvention'],
        SolarEventConvention.hindu,
      ),
      lunarLimb: _enumByName(
        LunarLimb.values,
        json['lunarLimb'],
        LunarLimb.upperLimb,
      ),
      lunarRefraction: _enumByName(
        LunarRefraction.values,
        json['lunarRefraction'],
        LunarRefraction.standard,
      ),
      timezoneId: _nonEmptyString(json['timezoneId']),
      observance: FestivalObservancePolicy.fromJson(
        rawObservance is Map
            ? rawObservance.map((key, value) => MapEntry(key.toString(), value))
            : null,
      ),
      nodeConvention: _enumByName(
        NodeConvention.values,
        json['nodeConvention'],
        NodeConvention.meanNode,
      ),
      regionalRuleSetId: _nonEmptyString(json['regionalRuleSetId']),
      calculationVersion: json['calculationVersion'] is int
          ? json['calculationVersion'] as int
          : kPanchangCalculationVersion,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PanchangProfile &&
        other.school == school &&
        other.ayanamsa == ayanamsa &&
        other.monthSystem == monthSystem &&
        other.solarConvention == solarConvention &&
        other.lunarLimb == lunarLimb &&
        other.lunarRefraction == lunarRefraction &&
        other.timezoneId == timezoneId &&
        other.observance == observance &&
        other.nodeConvention == nodeConvention &&
        other.regionalRuleSetId == regionalRuleSetId &&
        other.calculationVersion == calculationVersion;
  }

  @override
  int get hashCode => Object.hash(
    school,
    ayanamsa,
    monthSystem,
    solarConvention,
    lunarLimb,
    lunarRefraction,
    timezoneId,
    observance,
    nodeConvention,
    regionalRuleSetId,
    calculationVersion,
  );

  @override
  String toString() => 'PanchangProfile($cacheKey)';
}

/// Parses a stored enum identifier by `.name`, falling back to [fallback].
T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

/// Resolves a Swiss Ephemeris sidereal-mode integer to a [SiderealMode].
SiderealMode _siderealModeFromConstant(Object? raw) {
  if (raw is! int) return SiderealMode.lahiri;
  for (final mode in SiderealMode.values) {
    if (mode.constant == raw) return mode;
  }
  return SiderealMode.lahiri;
}

ObservanceCheckpoint? _checkpointByName(String raw) {
  for (final checkpoint in ObservanceCheckpoint.values) {
    if (checkpoint.name == raw) return checkpoint;
  }
  return null;
}

String? _nonEmptyString(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}
