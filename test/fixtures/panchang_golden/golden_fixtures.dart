import 'dart:convert';
import 'dart:io';

/// Directory that holds the locked Panchang golden fixtures.
const String kGoldenFixtureDirectory = 'test/fixtures/panchang_golden';

/// Panchang output fixture (date, place, profile, expected values).
const String kGoldenPanchangFileName = 'india_drik_lahiri_amanta.json';

/// Festival-resolution fixture (expected IDs, joined by `caseId`).
const String kGoldenFestivalFileName = 'festival_resolution.json';

/// Source of the festival rule catalog. Only IDs are referenced by fixtures.
const String kFestivalCatalogPath = 'assets/festivals.json';

/// Allowed provenance kinds. Only `external-verified` claims an external
/// accuracy check; the Phase 0 baseline is a regression lock.
const Set<String> kGoldenSourceKinds = {
  'engine-characterization',
  'provided-anchor',
  'external-verified',
};

/// Tags a fixture case may carry. The validation test requires the union to
/// cover [kGoldenRequiredTags].
const Set<String> kGoldenTags = {
  'kshaya',
  'vriddhi',
  'ekadashi',
  'mahashivratri',
  'janmashtami',
  'diwali',
  'holi',
  'ram_navami',
  'sankranti',
  'adhika',
  'new-moon',
  'sunrise-boundary',
  'bengali-transition',
  'moonrise-festival',
  'karva-chauth',
  'durga-puja',
  'regional',
  'ephemeris-boundary',
  'amanta-purnimanta',
  'known-gap',
};

/// Coverage the locked dataset must retain.
const Set<String> kGoldenRequiredTags = {
  'kshaya',
  'vriddhi',
  'ekadashi',
  'mahashivratri',
  'janmashtami',
  'diwali',
  'holi',
  'ram_navami',
  'sankranti',
  'adhika',
  'sunrise-boundary',
  'bengali-transition',
  'moonrise-festival',
  'ephemeris-boundary',
  'amanta-purnimanta',
};

/// Cities the dataset must cover (prefix of the case id).
const Set<String> kGoldenCities = {
  'delhi',
  'kolkata',
  'mumbai',
  'varanasi',
  'chennai',
  'guwahati',
};

/// Thrown when a fixture is missing, malformed, or internally inconsistent.
class GoldenFixtureException implements Exception {
  GoldenFixtureException(this.message);

  final String message;

  @override
  String toString() => 'GoldenFixtureException: $message';
}

/// Loaded Panchang and festival fixtures plus the asset festival ID set.
class GoldenFixtureSet {
  const GoldenFixtureSet({
    required this.panchang,
    required this.festivals,
    required this.assetFestivalIds,
  });

  final GoldenPanchangFile panchang;
  final GoldenFestivalFile festivals;
  final Set<String> assetFestivalIds;

  /// Reads all fixture files from disk. Never writes.
  static GoldenFixtureSet load({
    String directory = kGoldenFixtureDirectory,
    String festivalsPath = kFestivalCatalogPath,
  }) {
    final panchangJson = _decodeFile(
      File('$directory/$kGoldenPanchangFileName'),
    );
    final festivalJson = _decodeFile(
      File('$directory/$kGoldenFestivalFileName'),
    );
    final assetJson = _decodeFile(File(festivalsPath));

    return GoldenFixtureSet(
      panchang: GoldenPanchangFile.fromJson(panchangJson),
      festivals: GoldenFestivalFile.fromJson(festivalJson),
      assetFestivalIds: _assetFestivalIds(assetJson),
    );
  }

  GoldenCase? caseById(String id) {
    for (final c in panchang.cases) {
      if (c.id == id) return c;
    }
    return null;
  }

  GoldenFestivalCase? festivalCaseById(String id) {
    for (final c in festivals.cases) {
      if (c.caseId == id) return c;
    }
    return null;
  }
}

/// Structural checks that do not need the app's domain constants.
///
/// Returns human-readable errors; an empty list means the files are
/// structurally sound. Semantic checks (canonical tithi/nakshatra names,
/// festival IDs, coverage) live in the test that owns the app models.
List<String> validateGoldenStructure(GoldenFixtureSet set) {
  final errors = <String>[];

  void check(bool condition, String message) {
    if (!condition) errors.add(message);
  }

  final panchang = set.panchang;
  final festivals = set.festivals;

  check(panchang.schemaVersion == 1, 'panchang.schemaVersion must be 1');
  check(festivals.schemaVersion == 1, 'festivals.schemaVersion must be 1');
  check(
    panchang.profileId == festivals.profileId,
    'profileId differs between files: '
    '${panchang.profileId} vs ${festivals.profileId}',
  );
  check(
    panchang.profileId == 'india_drik_lahiri_amanta',
    'unexpected profileId ${panchang.profileId}',
  );
  check(
    panchang.profile.monthSystem == 'amanta',
    'profile.monthSystem must be amanta',
  );
  check(
    panchang.profile.ayanamsa == 'lahiri',
    'profile.ayanamsa must be lahiri',
  );
  check(
    panchang.profile.timezone == 'Asia/Kolkata',
    'profile.timezone must be Asia/Kolkata',
  );
  check(
    panchang.profile.calculationVersion > 0,
    'profile.calculationVersion must be positive',
  );
  check(panchang.tolerance.eventSeconds > 0, 'eventSeconds must be positive');
  check(
    panchang.tolerance.longitudeArcseconds > 0,
    'longitudeArcseconds must be positive',
  );

  final ids = <String>{};
  final caseIds = <String>{};
  final tagUnion = <String>{};
  final cityUnion = <String>{};
  final dateUnion = <DateTime>{};

  for (var i = 0; i < panchang.cases.length; i++) {
    final c = panchang.cases[i];
    final path = 'cases[$i] (${c.id})';

    check(c.id.isNotEmpty, '$path: empty id');
    check(ids.add(c.id), '$path: duplicate id ${c.id}');
    check(
      c.id.endsWith(c.dateString),
      '$path: id must end with the date ${c.dateString}',
    );
    caseIds.add(c.id);

    final city = c.id.split('-').first;
    check(kGoldenCities.contains(city), '$path: unknown city prefix "$city"');
    cityUnion.add(city);
    dateUnion.add(DateTime(c.date.year, c.date.month, c.date.day));

    final loc = c.location;
    check(loc.name.isNotEmpty, '$path: empty location name');
    check(
      loc.latitude >= -90 && loc.latitude <= 90,
      '$path: latitude out of range',
    );
    check(
      loc.longitude >= -180 && loc.longitude <= 180,
      '$path: longitude out of range',
    );
    check(
      loc.altitudeMeters >= -500 && loc.altitudeMeters <= 9000,
      '$path: implausible altitude',
    );
    check(loc.timezone.isNotEmpty, '$path: empty timezone');

    final e = c.expected;
    _checkInstant(errors, path, 'sunrise', e.sunrise);
    _checkInstant(errors, path, 'sunset', e.sunset);
    if (e.tithiEndsAt != null) {
      _checkInstant(errors, path, 'tithiEndsAt', e.tithiEndsAt!);
    }
    if (e.moonrise != null) {
      _checkInstant(errors, path, 'moonrise', e.moonrise!);
    }

    check(
      e.sunrise.localDate == c.dateString,
      '$path: sunrise ${e.sunrise.raw} is not on ${c.dateString}',
    );
    check(
      e.sunset.localDate == c.dateString,
      '$path: sunset ${e.sunset.raw} is not on ${c.dateString}',
    );
    if (e.moonrise != null) {
      check(
        e.moonrise!.localDate == c.dateString,
        '$path: moonrise ${e.moonrise!.raw} is not on ${c.dateString}',
      );
    }
    if (e.tithiEndsAt != null) {
      final end = e.tithiEndsAt!;
      check(
        end.localDate == c.dateString ||
            end.localDate == _nextDateString(c.date),
        '$path: tithiEndsAt ${end.raw} is outside the case day window',
      );
      check(
        end.instant.isAfter(e.sunrise.instant),
        '$path: tithiEndsAt must be after sunrise',
      );
      check(
        end.instant.difference(e.sunrise.instant) <= const Duration(hours: 30),
        '$path: tithiEndsAt is implausibly far after sunrise',
      );
    }
    check(
      (e.tithiEndsAt == null) == (e.nextTithi == null),
      '$path: tithiEndsAt and nextTithi must both be null or both be set',
    );

    _checkTithi(errors, path, 'tithiAtSunrise', e.tithiAtSunrise);
    if (e.nextTithi != null) {
      _checkTithi(errors, path, 'nextTithi', e.nextTithi!);
    }

    check(e.nakshatraAtSunrise.isNotEmpty, '$path: empty nakshatraAtSunrise');
    check(e.yogaAtSunrise.isNotEmpty, '$path: empty yogaAtSunrise');
    check(e.karanaAtSunrise.isNotEmpty, '$path: empty karanaAtSunrise');
    check(
      e.sunLongitude >= 0 && e.sunLongitude < 360,
      '$path: sunLongitude out of [0, 360)',
    );
    check(
      e.moonLongitude >= 0 && e.moonLongitude < 360,
      '$path: moonLongitude out of [0, 360)',
    );
    check(e.masa.isNotEmpty, '$path: empty masa');
    check(e.masaPurnimanta.isNotEmpty, '$path: empty masaPurnimanta');
    check(
      e.adhika == e.masa.startsWith('Adhika_'),
      '$path: adhika does not match the Adhika_ masa prefix',
    );

    for (final tag in c.tags) {
      check(kGoldenTags.contains(tag), '$path: unknown tag "$tag"');
      tagUnion.add(tag);
    }
    check(c.tags.isNotEmpty, '$path: no tags');

    check(
      kGoldenSourceKinds.contains(c.source.kind),
      '$path: unknown source.kind "${c.source.kind}"',
    );
    check(c.source.authority.isNotEmpty, '$path: empty source.authority');
    check(c.source.notes.isNotEmpty, '$path: empty source.notes');
    check(
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(c.source.retrievedOn),
      '$path: source.retrievedOn must be YYYY-MM-DD',
    );
    check(c.tolerance.eventSeconds > 0, '$path: eventSeconds must be positive');
    check(
      c.tolerance.longitudeArcseconds > 0,
      '$path: longitudeArcseconds must be positive',
    );
  }

  final festivalIds = <String>{};
  for (var i = 0; i < festivals.cases.length; i++) {
    final f = festivals.cases[i];
    final path = 'festival cases[$i] (${f.caseId})';
    check(f.caseId.isNotEmpty, '$path: empty caseId');
    check(festivalIds.add(f.caseId), '$path: duplicate caseId ${f.caseId}');
    check(caseIds.contains(f.caseId), '$path: no matching panchang case');
    check(
      _isSortedUnique(f.expectedFestivalIds),
      '$path: expectedFestivalIds must be sorted and unique',
    );
  }
  for (final id in caseIds) {
    check(festivalIds.contains(id), 'missing festival resolution for case $id');
  }

  check(
    panchang.cases.length >= 60,
    'dataset must keep at least 60 cases '
    '(found ${panchang.cases.length})',
  );
  check(
    panchang.cases.length <= 120,
    'dataset must stay small (max 120 cases, found ${panchang.cases.length})',
  );
  check(
    dateUnion.length >= 10,
    'dataset must cover at least 10 dates (found ${dateUnion.length})',
  );
  check(
    dateUnion.length <= 20,
    'dataset must stay within 20 dates (found ${dateUnion.length})',
  );
  for (final city in kGoldenCities) {
    check(cityUnion.contains(city), 'dataset must cover $city');
  }
  for (final tag in kGoldenRequiredTags) {
    check(tagUnion.contains(tag), 'dataset must retain the "$tag" case');
  }

  return errors;
}

void _checkInstant(
  List<String> errors,
  String path,
  String field,
  GoldenInstant value,
) {
  if (!value.hasExplicitOffset) {
    errors.add('$path: $field must carry an explicit UTC offset');
  }
}

void _checkTithi(
  List<String> errors,
  String path,
  String field,
  GoldenTithi value,
) {
  if (value.paksha != 'Shukla' && value.paksha != 'Krishna') {
    errors.add('$path: $field.paksha must be Shukla or Krishna');
  }
  if (value.number < 1 || value.number > 15) {
    errors.add('$path: $field.number must be 1..15');
  }
  if (value.name.isEmpty) {
    errors.add('$path: $field.name is empty');
  }
}

String _nextDateString(DateTime date) {
  final next = DateTime(date.year, date.month, date.day + 1);
  return _dateString(next);
}

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

bool _isSortedUnique(List<String> values) {
  for (var i = 1; i < values.length; i++) {
    if (values[i - 1].compareTo(values[i]) >= 0) return false;
  }
  return true;
}

Object? _decodeFile(File file) {
  if (!file.existsSync()) {
    throw GoldenFixtureException('Missing fixture file: ${file.path}');
  }
  try {
    return jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    throw GoldenFixtureException('Invalid JSON in ${file.path}: ${e.message}');
  }
}

Set<String> _assetFestivalIds(Object? json) {
  final list = _asList(json, kFestivalCatalogPath);
  final ids = <String>{};
  for (var i = 0; i < list.length; i++) {
    final map = _asMap(list[i], '$kFestivalCatalogPath[$i]');
    final id = _asString(map['id'], '$kFestivalCatalogPath[$i].id');
    if (!ids.add(id)) {
      throw GoldenFixtureException(
        '$kFestivalCatalogPath: duplicate festival id "$id"',
      );
    }
  }
  return ids;
}

class GoldenPanchangFile {
  const GoldenPanchangFile({
    required this.schemaVersion,
    required this.profileId,
    required this.profile,
    required this.source,
    required this.tolerance,
    required this.cases,
  });

  final int schemaVersion;
  final String profileId;
  final GoldenProfile profile;
  final GoldenSource source;
  final GoldenTolerance tolerance;
  final List<GoldenCase> cases;

  factory GoldenPanchangFile.fromJson(Object? json) {
    final map = _asMap(json, 'panchang');
    final source = GoldenSource.fromJson(map['source'], 'panchang.source');
    final tolerance = GoldenTolerance.fromJson(
      map['tolerance'],
      'panchang.tolerance',
    );
    final casesJson = _asList(map['cases'], 'panchang.cases');
    return GoldenPanchangFile(
      schemaVersion: _asInt(map['schemaVersion'], 'panchang.schemaVersion'),
      profileId: _asString(map['profileId'], 'panchang.profileId'),
      profile: GoldenProfile.fromJson(map['profile'], 'panchang.profile'),
      source: source,
      tolerance: tolerance,
      cases: [
        for (var i = 0; i < casesJson.length; i++)
          GoldenCase.fromJson(
            casesJson[i],
            'panchang.cases[$i]',
            source,
            tolerance,
          ),
      ],
    );
  }
}

class GoldenProfile {
  const GoldenProfile({
    required this.engineVersion,
    required this.ayanamsa,
    required this.monthSystem,
    required this.sunriseConvention,
    required this.timezone,
    required this.calculationVersion,
  });

  final String engineVersion;
  final String ayanamsa;
  final String monthSystem;
  final String sunriseConvention;
  final String timezone;
  final int calculationVersion;

  factory GoldenProfile.fromJson(Object? json, String path) {
    final map = _asMap(json, path);
    return GoldenProfile(
      engineVersion: _asString(map['engineVersion'], '$path.engineVersion'),
      ayanamsa: _asString(map['ayanamsa'], '$path.ayanamsa'),
      monthSystem: _asString(map['monthSystem'], '$path.monthSystem'),
      sunriseConvention: _asString(
        map['sunriseConvention'],
        '$path.sunriseConvention',
      ),
      timezone: _asString(map['timezone'], '$path.timezone'),
      calculationVersion: _asInt(
        map['calculationVersion'],
        '$path.calculationVersion',
      ),
    );
  }
}

class GoldenSource {
  const GoldenSource({
    required this.authority,
    required this.retrievedOn,
    required this.kind,
    required this.notes,
  });

  final String authority;
  final String retrievedOn;
  final String kind;
  final String notes;

  factory GoldenSource.fromJson(Object? json, String path) {
    final map = _asMap(json, path);
    return GoldenSource(
      authority: _asString(map['authority'], '$path.authority'),
      retrievedOn: _asString(map['retrievedOn'], '$path.retrievedOn'),
      kind: _asString(map['kind'], '$path.kind'),
      notes: _asString(map['notes'], '$path.notes'),
    );
  }
}

class GoldenTolerance {
  const GoldenTolerance({
    required this.eventSeconds,
    required this.longitudeArcseconds,
  });

  final int eventSeconds;
  final double longitudeArcseconds;

  factory GoldenTolerance.fromJson(Object? json, String path) {
    final map = _asMap(json, path);
    return GoldenTolerance(
      eventSeconds: _asInt(map['eventSeconds'], '$path.eventSeconds'),
      longitudeArcseconds: _asDouble(
        map['longitudeArcseconds'],
        '$path.longitudeArcseconds',
      ),
    );
  }
}

class GoldenCase {
  const GoldenCase({
    required this.id,
    required this.location,
    required this.date,
    required this.tags,
    required this.expected,
    required this.source,
    required this.tolerance,
  });

  final String id;
  final GoldenLocation location;
  final DateTime date;
  final List<String> tags;
  final GoldenExpected expected;
  final GoldenSource source;
  final GoldenTolerance tolerance;

  String get dateString => _dateString(date);

  factory GoldenCase.fromJson(
    Object? json,
    String path,
    GoldenSource defaultSource,
    GoldenTolerance defaultTolerance,
  ) {
    final map = _asMap(json, path);
    final sourceJson = map['source'];
    final toleranceJson = map['tolerance'];
    return GoldenCase(
      id: _asString(map['id'], '$path.id'),
      location: GoldenLocation.fromJson(map['location'], '$path.location'),
      date: _asDateOnly(map['date'], '$path.date'),
      tags: _asStringList(map['tags'], '$path.tags'),
      expected: GoldenExpected.fromJson(map['expected'], '$path.expected'),
      source: sourceJson == null
          ? defaultSource
          : GoldenSource.fromJson(sourceJson, '$path.source'),
      tolerance: toleranceJson == null
          ? defaultTolerance
          : GoldenTolerance.fromJson(toleranceJson, '$path.tolerance'),
    );
  }
}

class GoldenLocation {
  const GoldenLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.timezone,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final String timezone;

  factory GoldenLocation.fromJson(Object? json, String path) {
    final map = _asMap(json, path);
    return GoldenLocation(
      name: _asString(map['name'], '$path.name'),
      latitude: _asDouble(map['latitude'], '$path.latitude'),
      longitude: _asDouble(map['longitude'], '$path.longitude'),
      altitudeMeters: _asDouble(map['altitudeMeters'], '$path.altitudeMeters'),
      timezone: _asString(map['timezone'], '$path.timezone'),
    );
  }
}

class GoldenExpected {
  const GoldenExpected({
    required this.sunrise,
    required this.sunset,
    required this.tithiAtSunrise,
    required this.tithiEndsAt,
    required this.nextTithi,
    required this.nakshatraAtSunrise,
    required this.yogaAtSunrise,
    required this.karanaAtSunrise,
    required this.sunLongitude,
    required this.moonLongitude,
    required this.masa,
    required this.masaPurnimanta,
    required this.adhika,
    required this.moonrise,
    required this.bengaliDate,
  });

  final GoldenInstant sunrise;
  final GoldenInstant sunset;
  final GoldenTithi tithiAtSunrise;
  final GoldenInstant? tithiEndsAt;
  final GoldenTithi? nextTithi;
  final String nakshatraAtSunrise;
  final String yogaAtSunrise;
  final String karanaAtSunrise;
  final double sunLongitude;
  final double moonLongitude;
  final String masa;
  final String masaPurnimanta;
  final bool adhika;
  final GoldenInstant? moonrise;
  final GoldenBengaliDate? bengaliDate;

  factory GoldenExpected.fromJson(Object? json, String path) {
    final map = _asMap(json, path);
    final tithiEndsAt = map['tithiEndsAt'];
    final nextTithi = map['nextTithi'];
    final moonrise = map['moonrise'];
    final bengaliDate = map['bengaliDate'];
    return GoldenExpected(
      sunrise: GoldenInstant.fromJson(map['sunrise'], '$path.sunrise'),
      sunset: GoldenInstant.fromJson(map['sunset'], '$path.sunset'),
      tithiAtSunrise: GoldenTithi.fromJson(
        map['tithiAtSunrise'],
        '$path.tithiAtSunrise',
      ),
      tithiEndsAt: tithiEndsAt == null
          ? null
          : GoldenInstant.fromJson(tithiEndsAt, '$path.tithiEndsAt'),
      nextTithi: nextTithi == null
          ? null
          : GoldenTithi.fromJson(nextTithi, '$path.nextTithi'),
      nakshatraAtSunrise: _asString(
        map['nakshatraAtSunrise'],
        '$path.nakshatraAtSunrise',
      ),
      yogaAtSunrise: _asString(map['yogaAtSunrise'], '$path.yogaAtSunrise'),
      karanaAtSunrise: _asString(
        map['karanaAtSunrise'],
        '$path.karanaAtSunrise',
      ),
      sunLongitude: _asDouble(map['sunLongitude'], '$path.sunLongitude'),
      moonLongitude: _asDouble(map['moonLongitude'], '$path.moonLongitude'),
      masa: _asString(map['masa'], '$path.masa'),
      masaPurnimanta: _asString(map['masaPurnimanta'], '$path.masaPurnimanta'),
      adhika: _asBool(map['adhika'], '$path.adhika'),
      moonrise: moonrise == null
          ? null
          : GoldenInstant.fromJson(moonrise, '$path.moonrise'),
      bengaliDate: bengaliDate == null
          ? null
          : GoldenBengaliDate.fromJson(bengaliDate, '$path.bengaliDate'),
    );
  }
}

class GoldenTithi {
  const GoldenTithi({
    required this.paksha,
    required this.number,
    required this.name,
  });

  final String paksha;
  final int number;
  final String name;

  factory GoldenTithi.fromJson(Object? json, String path) {
    final map = _asMap(json, path);
    return GoldenTithi(
      paksha: _asString(map['paksha'], '$path.paksha'),
      number: _asInt(map['number'], '$path.number'),
      name: _asString(map['name'], '$path.name'),
    );
  }
}

class GoldenBengaliDate {
  const GoldenBengaliDate({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final String month;
  final int day;

  factory GoldenBengaliDate.fromJson(Object? json, String path) {
    final map = _asMap(json, path);
    return GoldenBengaliDate(
      year: _asInt(map['year'], '$path.year'),
      month: _asString(map['month'], '$path.month'),
      day: _asInt(map['day'], '$path.day'),
    );
  }
}

class GoldenFestivalFile {
  const GoldenFestivalFile({
    required this.schemaVersion,
    required this.profileId,
    required this.source,
    required this.cases,
  });

  final int schemaVersion;
  final String profileId;
  final GoldenSource source;
  final List<GoldenFestivalCase> cases;

  factory GoldenFestivalFile.fromJson(Object? json) {
    final map = _asMap(json, 'festivals');
    final casesJson = _asList(map['cases'], 'festivals.cases');
    return GoldenFestivalFile(
      schemaVersion: _asInt(map['schemaVersion'], 'festivals.schemaVersion'),
      profileId: _asString(map['profileId'], 'festivals.profileId'),
      source: GoldenSource.fromJson(map['source'], 'festivals.source'),
      cases: [
        for (var i = 0; i < casesJson.length; i++)
          GoldenFestivalCase.fromJson(casesJson[i], 'festivals.cases[$i]'),
      ],
    );
  }
}

class GoldenFestivalCase {
  const GoldenFestivalCase({
    required this.caseId,
    required this.expectedFestivalIds,
    this.notes,
  });

  final String caseId;
  final List<String> expectedFestivalIds;
  final String? notes;

  factory GoldenFestivalCase.fromJson(Object? json, String path) {
    final map = _asMap(json, path);
    final notes = map['notes'];
    return GoldenFestivalCase(
      caseId: _asString(map['caseId'], '$path.caseId'),
      expectedFestivalIds: _asStringList(
        map['expectedFestivalIds'],
        '$path.expectedFestivalIds',
        allowEmpty: true,
      ),
      notes: notes == null ? null : _asString(notes, '$path.notes'),
    );
  }
}

class GoldenInstant {
  const GoldenInstant({required this.raw, required this.instant});

  /// Original ISO-8601 string, including the explicit offset.
  final String raw;

  /// Parsed instant. A string with an offset parses as UTC.
  final DateTime instant;

  bool get hasExplicitOffset => RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);

  String get localDate => raw.substring(0, 10);

  factory GoldenInstant.fromJson(Object? json, String path) {
    final raw = _asString(json, path);
    final instant = DateTime.tryParse(raw);
    if (instant == null) {
      throw GoldenFixtureException('$path: invalid ISO-8601 "$raw"');
    }
    return GoldenInstant(raw: raw, instant: instant);
  }

  @override
  String toString() => raw;
}

Map<String, dynamic> _asMap(Object? value, String path) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  throw GoldenFixtureException(
    '$path: expected an object, got ${value.runtimeType}',
  );
}

List<dynamic> _asList(Object? value, String path) {
  if (value is List) return value;
  throw GoldenFixtureException(
    '$path: expected a list, got ${value.runtimeType}',
  );
}

String _asString(Object? value, String path) {
  if (value is String) return value;
  throw GoldenFixtureException(
    '$path: expected a string, got ${value.runtimeType}',
  );
}

int _asInt(Object? value, String path) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw GoldenFixtureException(
    '$path: expected an integer, got ${value.runtimeType}',
  );
}

double _asDouble(Object? value, String path) {
  if (value is num) return value.toDouble();
  throw GoldenFixtureException(
    '$path: expected a number, got ${value.runtimeType}',
  );
}

bool _asBool(Object? value, String path) {
  if (value is bool) return value;
  throw GoldenFixtureException(
    '$path: expected a boolean, got ${value.runtimeType}',
  );
}

DateTime _asDateOnly(Object? value, String path) {
  final raw = _asString(value, path);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
    throw GoldenFixtureException('$path: expected YYYY-MM-DD, got "$raw"');
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw GoldenFixtureException('$path: invalid date "$raw"');
  }
  return parsed;
}

List<String> _asStringList(
  Object? value,
  String path, {
  bool allowEmpty = false,
}) {
  final list = _asList(value, path);
  final result = <String>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is! String || item.isEmpty) {
      throw GoldenFixtureException('$path[$i]: expected a non-empty string');
    }
    result.add(item);
  }
  if (!allowEmpty && result.isEmpty) {
    throw GoldenFixtureException('$path: must not be empty');
  }
  return result;
}
