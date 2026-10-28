// Calibration harness for the Surya Siddhanta Panjika school.
//
// The classical text has no bija (seed) correction, so its mean motions drift
// against a printed panjika: by 2026 the Moon is up to ~12 degrees (a full
// tithi) behind true sidereal, and the Sun ~4.7 degrees. Matching a specific
// authority such as Gupta Press therefore needs a calibrated
// [SuryaSiddhantaTuning], and this tool is how that tuning is derived.
//
// Usage (from the repo root):
//
//   dart run tool/surya_siddhanta_probe.dart probe 2026-01-15 2026-04-14 2026-10-28
//   dart run tool/surya_siddhanta_probe.dart probe --range 2026-01-01 2026-12-31 --step 30
//   dart run tool/surya_siddhanta_probe.dart fit path/to/reference.csv
//
// `probe` prints the Surya Siddhanta values for a date so a printed panjika can
// be compared by eye. `fit` solves a tuning from reference rows.
//
// The probe is deliberately pure Dart: it imports only the engine, never the
// Flutter/Jyotish stack, so `dart run` works. The Drik comparison lives in the
// app and in `test/surya_siddhanta_engine_test.dart`.
//
// Reference CSV for `fit`, header required. Accepted columns:
//
//   date,sun,moon      sidereal longitudes in degrees (best: fully determined)
//   date,tithi         elapsed tithi 1..30 (as printed)
//
// `date` is an ISO date (`2026-04-14`) or an ISO instant
// (`2026-04-14T06:00:00+05:30`). A bare date is read at 06:00 local, which is
// after sunrise for India and matches how panjikas label a civil day.
//
// This is a developer tool. It never runs in the app.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:tithi/services/panchang/ephemeris/surya_siddhanta_engine.dart';

const String _usage = '''
Surya Siddhanta calibration probe

  dart run tool/surya_siddhanta_probe.dart probe <date> [<date> ...]
  dart run tool/surya_siddhanta_probe.dart probe --range <from> <to> [--step <days>]
  dart run tool/surya_siddhanta_probe.dart fit <reference.csv>

Dates accept `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SS+HH:MM`.
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    stdout.writeln(_usage);
    return;
  }

  switch (args.first) {
    case 'probe':
      await _probe(args.sublist(1));
    case 'fit':
      if (args.length < 2) {
        stderr.writeln('fit needs a CSV path.\n\n$_usage');
        exitCode = 64;
        return;
      }
      await _fit(args[1]);
    default:
      stderr.writeln('Unknown command "${args.first}".\n\n$_usage');
      exitCode = 64;
  }
}

// --- probe -----------------------------------------------------------------

Future<void> _probe(List<String> args) async {
  final instants = <DateTime>[];

  if (args.isNotEmpty && args.first == '--range') {
    if (args.length < 3) {
      stderr.writeln('--range needs <from> <to>.\n\n$_usage');
      exitCode = 64;
      return;
    }
    final from = _parseDate(args[1]);
    final to = _parseDate(args[2]);
    final stepIndex = args.indexOf('--step');
    final stepDays = stepIndex >= 0 && stepIndex + 1 < args.length
        ? int.parse(args[stepIndex + 1])
        : 30;
    if (stepDays < 1) {
      stderr.writeln('--step must be at least 1 day.');
      exitCode = 64;
      return;
    }
    for (var d = from; !d.isAfter(to); d = d.add(Duration(days: stepDays))) {
      instants.add(d);
    }
  } else {
    for (final raw in args) {
      instants.add(_parseDate(raw));
    }
  }

  if (instants.isEmpty) {
    stderr.writeln('No dates given.\n\n$_usage');
    exitCode = 64;
    return;
  }

  const engine = SuryaSiddhantaEngine();

  stdout.writeln(
    '${'instant'.padRight(26)}'
    '${'sun'.padLeft(9)}'
    '${'moon'.padLeft(9)}'
    '${'tithi'.padLeft(9)}'
    '${'nakshatra'.padLeft(14)}'
    '${'ahargana'.padLeft(16)}',
  );
  stdout.writeln('-' * 84);

  for (final instant in instants) {
    final ss = engine.longitudesAt(instant);
    final ssTithi = _tithi(ss.moon - ss.sun);
    final ssNak = _nakshatra(ss.moon);
    final ahargana = SuryaSiddhantaEngine.aharganaAt(instant);

    stdout.writeln(
      '${_format(instant).padRight(26)}'
      '${ss.sun.toStringAsFixed(3).padLeft(9)}'
      '${ss.moon.toStringAsFixed(3).padLeft(9)}'
      '${ssTithi.toStringAsFixed(3).padLeft(9)}'
      '${ssNak.padLeft(14)}'
      '${ahargana.toStringAsFixed(4).padLeft(16)}',
    );
  }

  stdout.writeln();
  stdout.writeln('tuning: ${engine.tuning.tag}');
  stdout.writeln(
    'A printed panjika usually gives tithi and nakshatra, not longitudes. '
    'Record those in a CSV and run `fit` to derive a tuning.',
  );
}

// --- fit -------------------------------------------------------------------

Future<void> _fit(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No such file: $path');
    exitCode = 66;
    return;
  }

  final rows = _readReferenceCsv(file.readAsLinesSync());
  if (rows.isEmpty) {
    stderr.writeln(
      'No usable rows in $path. Expected a header plus rows of '
      '`date,sun,moon` or `date,tithi`.',
    );
    exitCode = 65;
    return;
  }

  final mode = rows.first.hasLongitudes ? 'longitudes' : 'tithi';
  stdout.writeln(
    'Fitting ${rows.length} reference rows ($mode) with a '
    '${SuryaSiddhantaTuning.classical.tag} starting point.',
  );

  // Epoch offset and annual bija are nearly collinear over a short baseline:
  // over one year almost any split between them fits equally well, and the
  // resulting parameters extrapolate wildly outside the sample. Only let the
  // fit move the bija when the references actually span enough years to
  // separate a constant from a trend.
  final years = rows
      .map(
        (r) =>
            SuryaSiddhantaEngine.aharganaAt(r.instant) /
            kSuryaSiddhantaSolarYear,
      )
      .toList();
  final spanYears = years.reduce(math.max) - years.reduce(math.min);
  const minSpanYearsForBija = 10.0;
  final allowBija = spanYears >= minSpanYearsForBija;

  if (!allowBija) {
    stdout.writeln(
      'Note: references span only ${spanYears.toStringAsFixed(1)} years, so '
      'only the epoch offset is fitted. Supply dates spanning at least '
      '${minSpanYearsForBija.toInt()}+ years to calibrate the annual bija.',
    );
  }

  var tuning = SuryaSiddhantaTuning.classical;
  for (var iteration = 0; iteration < 60; iteration++) {
    final fitted = _fitOnce(rows, tuning, allowBija: allowBija);
    final moved = _maxAbsDelta(tuning, fitted);
    tuning = fitted;
    if (moved < 1e-10) break;
  }

  final engine = SuryaSiddhantaEngine(tuning: tuning);
  final residual = _residuals(rows, engine);

  stdout.writeln();
  stdout.writeln('Fitted tuning:');
  stdout.writeln(_tuningSnippet(tuning));
  stdout.writeln();
  stdout.writeln(
    'Residuals: max ${residual.max.abs().toStringAsFixed(4)}, '
    'rms ${residual.rms.toStringAsFixed(4)} '
    '${mode == 'tithi' ? 'tithi' : 'degrees'}',
  );
  if (residual.max.abs() > 0.5 && mode == 'tithi') {
    stdout.writeln(
      'A tithi residual above 0.5 means the reference dates cannot be matched '
      'by epoch offset + linear bija alone. Check the panjika convention '
      '(sunrise vs midnight labelling) before tightening the model.',
    );
  }
}

// Parameter slots, in the order the normal equations use them.
const int _kSunEpoch = 0;
const int _kSunBija = 1;
const int _kMoonEpoch = 2;
const int _kMoonBija = 3;
const int _kApsisEpoch = 4;
const int _kApsisBija = 5;

/// Annual rates, i.e. the parameters a short baseline cannot separate from an
/// epoch offset.
bool _isBija(int slot) =>
    slot == _kSunBija || slot == _kMoonBija || slot == _kApsisBija;

List<double> _paramsOf(SuryaSiddhantaTuning t) => [
  t.sunEpochLongitude,
  t.sunBijaArcSecondsPerYear,
  t.moonEpochLongitude,
  t.moonBijaArcSecondsPerYear,
  t.moonApsisEpochLongitude,
  t.moonApsisBijaArcSecondsPerYear,
];

SuryaSiddhantaTuning _tuningOf(List<double> v) => SuryaSiddhantaTuning(
  sunEpochLongitude: v[_kSunEpoch],
  sunBijaArcSecondsPerYear: v[_kSunBija],
  moonEpochLongitude: v[_kMoonEpoch],
  moonBijaArcSecondsPerYear: v[_kMoonBija],
  moonApsisEpochLongitude: v[_kApsisEpoch],
  moonApsisBijaArcSecondsPerYear: v[_kApsisBija],
);

/// One Gauss-Newton step over every tuning parameter.
///
/// The Moon's manda correction is a function of the *apogee* longitude, not
/// only of the Moon's mean longitude, so the apogee epoch is a first-class
/// unknown here. Holding it at the text's 0 caps the achievable fit at several
/// degrees: the correction is worth up to 5.1 degrees and the classical text
/// anchors the apogee at 0 for the Kali epoch, which is not where it was.
///
/// The model is linear in each parameter once the current corrections are held
/// fixed, so one step is a plain least-squares solve; repeating it converges in
/// a few passes.
SuryaSiddhantaTuning _fitOnce(
  List<_ReferenceRow> rows,
  SuryaSiddhantaTuning tuning, {
  required bool allowBija,
}) {
  final params = _paramsOf(tuning);
  final residual = _residualVector(rows, tuning);
  final jacobian = _numericJacobian(rows, params, allowBija: allowBija);

  final n = params.length;
  final normal = List.generate(n, (_) => List<double>.filled(n, 0.0));
  final gradient = List<double>.filled(n, 0.0);

  for (var i = 0; i < n; i++) {
    for (var k = 0; k < residual.length; k++) {
      gradient[i] -= jacobian[k][i] * residual[k];
    }
    for (var j = 0; j < n; j++) {
      var sum = 0.0;
      for (var k = 0; k < residual.length; k++) {
        sum += jacobian[k][i] * jacobian[k][j];
      }
      normal[i][j] = sum;
    }
    // Ridge term: keeps the solve finite when a column is degenerate (bija
    // disabled, a single reference row, or a parameter that the samples
    // cannot see).
    normal[i][i] += 1e-9;
  }

  final step = _solve(normal, gradient);
  if (step == null) return tuning;

  final next = List<double>.from(params);
  for (var i = 0; i < n; i++) {
    if (!allowBija && _isBija(i)) continue;
    next[i] += step[i];
  }
  return _tuningOf(next);
}

/// Residuals in degrees, one or two entries per reference row.
List<double> _residualVector(
  List<_ReferenceRow> rows,
  SuryaSiddhantaTuning tuning,
) {
  final engine = SuryaSiddhantaEngine(tuning: tuning);
  final out = <double>[];

  for (final row in rows) {
    final ahargana = SuryaSiddhantaEngine.aharganaAt(row.instant);
    if (row.hasLongitudes) {
      out.add(_signed(row.sun! - engine.trueSunLongitude(ahargana)));
      out.add(_signed(row.moon! - engine.trueMoonLongitude(ahargana)));
      continue;
    }
    // A tithi row constrains only the elongation, which is one equation in two
    // unknowns; the least-squares step splits it by the bodies' relative
    // weight automatically because the Jacobian columns differ.
    final ssTithi = _tithi(
      engine.trueMoonLongitude(ahargana) - engine.trueSunLongitude(ahargana),
    );
    out.add(_signed(row.tithi! - ssTithi) * 12.0);
  }

  return out;
}

/// Finite-difference Jacobian, `J[row][parameter]`.
List<List<double>> _numericJacobian(
  List<_ReferenceRow> rows,
  List<double> params, {
  required bool allowBija,
}) {
  // Degrees for the longitudes, arc seconds for the annual rates: a single
  // step size would be either lost to cancellation or outside the linear
  // regime for the other parameter type.
  const steps = [1e-4, 1e-2, 1e-4, 1e-2, 1e-4, 1e-2];

  final base = _residualVector(rows, _tuningOf(params));
  final columns = List.generate(params.length, (_) => <double>[]);

  for (var i = 0; i < params.length; i++) {
    final step = (!allowBija && _isBija(i)) ? 0.0 : steps[i];
    if (step == 0.0) {
      columns[i] = List<double>.filled(base.length, 0.0);
      continue;
    }
    final probe = List<double>.from(params);
    probe[i] += step;
    final shifted = _residualVector(rows, _tuningOf(probe));
    columns[i] = List.generate(
      base.length,
      (k) => (shifted[k] - base[k]) / step,
    );
  }

  return List.generate(
    base.length,
    (k) => List.generate(params.length, (i) => columns[i][k]),
  );
}

/// Gaussian elimination with partial pivoting. Returns null if singular.
List<double>? _solve(List<List<double>> a, List<double> b) {
  final n = b.length;
  final m = [
    for (var i = 0; i < n; i++) [...a[i], b[i]],
  ];

  for (var col = 0; col < n; col++) {
    var pivot = col;
    for (var row = col + 1; row < n; row++) {
      if (m[row][col].abs() > m[pivot][col].abs()) pivot = row;
    }
    if (m[pivot][col].abs() < 1e-12) return null;

    final swap = m[col];
    m[col] = m[pivot];
    m[pivot] = swap;

    final diag = m[col][col];
    for (var j = col; j <= n; j++) {
      m[col][j] /= diag;
    }
    for (var row = 0; row < n; row++) {
      if (row == col) continue;
      final factor = m[row][col];
      if (factor == 0.0) continue;
      for (var j = col; j <= n; j++) {
        m[row][j] -= factor * m[col][j];
      }
    }
  }

  return [for (var i = 0; i < n; i++) m[i][n]];
}

({double max, double rms}) _residuals(
  List<_ReferenceRow> rows,
  SuryaSiddhantaEngine engine,
) {
  var maxAbs = 0.0;
  var sumSquares = 0.0;

  for (final row in rows) {
    final ahargana = SuryaSiddhantaEngine.aharganaAt(row.instant);
    double residual;
    if (row.hasLongitudes) {
      final sun = _signed(row.sun! - engine.trueSunLongitude(ahargana));
      final moon = _signed(row.moon! - engine.trueMoonLongitude(ahargana));
      residual = math.max(sun.abs(), moon.abs());
    } else {
      residual = _signed(
        row.tithi! -
            _tithi(
              engine.trueMoonLongitude(ahargana) -
                  engine.trueSunLongitude(ahargana),
            ),
      );
    }
    maxAbs = math.max(maxAbs, residual.abs());
    sumSquares += residual * residual;
  }

  return (max: maxAbs, rms: math.sqrt(sumSquares / rows.length));
}

double _maxAbsDelta(SuryaSiddhantaTuning a, SuryaSiddhantaTuning b) {
  return <double>[
    (b.sunEpochLongitude - a.sunEpochLongitude).abs(),
    (b.moonEpochLongitude - a.moonEpochLongitude).abs(),
    (b.moonApsisEpochLongitude - a.moonApsisEpochLongitude).abs(),
    (b.sunBijaArcSecondsPerYear - a.sunBijaArcSecondsPerYear).abs() / 3600,
    (b.moonBijaArcSecondsPerYear - a.moonBijaArcSecondsPerYear).abs() / 3600,
    (b.moonApsisBijaArcSecondsPerYear - a.moonApsisBijaArcSecondsPerYear)
            .abs() /
        3600,
  ].reduce(math.max);
}

String _tuningSnippet(SuryaSiddhantaTuning tuning) {
  String f(double v) => v.toStringAsFixed(6);
  return 'const SuryaSiddhantaTuning(\n'
      '  sunEpochLongitude: ${f(tuning.sunEpochLongitude)},\n'
      '  moonEpochLongitude: ${f(tuning.moonEpochLongitude)},\n'
      '  moonApsisEpochLongitude: ${f(tuning.moonApsisEpochLongitude)},\n'
      '  sunBijaArcSecondsPerYear: ${f(tuning.sunBijaArcSecondsPerYear)},\n'
      '  moonBijaArcSecondsPerYear: ${f(tuning.moonBijaArcSecondsPerYear)},\n'
      '  moonApsisBijaArcSecondsPerYear: '
      '${f(tuning.moonApsisBijaArcSecondsPerYear)},\n'
      ')';
}

// --- reference parsing -----------------------------------------------------

class _ReferenceRow {
  _ReferenceRow({required this.instant, this.sun, this.moon, this.tithi});

  final DateTime instant;
  final double? sun;
  final double? moon;
  final double? tithi;

  bool get hasLongitudes => sun != null && moon != null;
}

List<_ReferenceRow> _readReferenceCsv(List<String> lines) {
  final rows = <_ReferenceRow>[];
  var header = <String>[];

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final cells = line.split(',').map((c) => c.trim()).toList();

    if (header.isEmpty) {
      header = cells.map((c) => c.toLowerCase()).toList();
      if (!header.contains('date')) {
        stderr.writeln('CSV header must include a `date` column.');
        return const [];
      }
      continue;
    }

    String? cell(String name) {
      final index = header.indexOf(name);
      if (index < 0 || index >= cells.length) return null;
      final value = cells[index];
      return value.isEmpty ? null : value;
    }

    final dateCell = cell('date');
    if (dateCell == null) continue;

    final sun = double.tryParse(cell('sun') ?? '');
    final moon = double.tryParse(cell('moon') ?? '');
    final tithi = double.tryParse(cell('tithi') ?? '');
    if (sun == null && moon == null && tithi == null) continue;

    rows.add(
      _ReferenceRow(
        instant: _parseDate(dateCell),
        sun: sun,
        moon: moon,
        tithi: tithi,
      ),
    );
  }

  return rows;
}

// --- small helpers ---------------------------------------------------------

DateTime _parseDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    stderr.writeln('Cannot parse date "$raw". Use YYYY-MM-DD or an ISO instant.');
    exitCode = 64;
    return DateTime.utc(2000);
  }
  // A bare calendar date is read after sunrise (06:00 local), which is how a
  // panjika labels a civil day.
  if (!raw.contains('T')) {
    return DateTime(parsed.year, parsed.month, parsed.day, 6);
  }
  return parsed;
}

/// Elapsed tithi in 1..30.
double _tithi(double moonMinusSun) => _norm(moonMinusSun) / 12.0 + 1.0;

String _nakshatra(double moonLongitude) {
  const names = <String>[
    'Ashvini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra',
    'Punarvasu', 'Pushya', 'Ashlesha', 'Magha', 'PurvaPhalguni',
    'UttaraPhalguni', 'Hasta', 'Chitra', 'Svati', 'Vishakha', 'Anuradha',
    'Jyeshtha', 'Mula', 'PurvaShadha', 'UttaraShadha', 'Shravana',
    'Dhanishta', 'Shatabhisha', 'PurvaBhadrapada', 'UttaraBhadrapada',
    'Revati',
  ];
  final index = (_norm(moonLongitude) / (360.0 / 27.0)).floor() % 27;
  return names[index];
}

double _norm(double degrees) {
  final value = degrees % 360.0;
  return value < 0 ? value + 360.0 : value;
}

double _signed(double degrees) {
  final value = _norm(degrees);
  return value > 180.0 ? value - 360.0 : value;
}

String _format(DateTime instant) {
  String two(int v) => v.toString().padLeft(2, '0');
  final offset = instant.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final total = offset.inMinutes.abs();
  return '${instant.year}-${two(instant.month)}-${two(instant.day)} '
      '${two(instant.hour)}:${two(instant.minute)} '
      '$sign${two(total ~/ 60)}:${two(total % 60)}';
}
