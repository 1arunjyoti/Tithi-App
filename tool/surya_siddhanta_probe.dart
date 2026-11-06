// Calibration harness for the Surya Siddhanta Panjika school.
//
// The classical text anchors every mean longitude at 0 for the Kali epoch and
// carries no bija (seed) correction, so it does not land on a modern or
// printed frame: aligning the Sun to Lahiri alone needs an epoch offset near
// -11.6 degrees. Matching a specific panjika therefore needs a calibrated
// [SuryaSiddhantaTuning], and this tool is how that tuning is derived and
// checked.
//
// Usage (from the repo root):
//
//   dart run tool/surya_siddhanta_probe.dart check 2026-01-15 --tithi "Krishna Ekadashi"
//   dart run tool/surya_siddhanta_probe.dart check 2026-01-15 --tithi 26 --ends 09:20 --csv
//   dart run tool/surya_siddhanta_probe.dart probe 2026-01-15 2026-04-14 2026-10-28
//   dart run tool/surya_siddhanta_probe.dart probe --range 2026-01-01 2026-12-31 --step 30
//   dart run tool/surya_siddhanta_probe.dart fit path/to/reference.csv
//
// `check` compares one date against what a printed panjika says and flags
// comparisons that sit too close to a tithi boundary to be meaningful.
// `probe` prints the raw values for a range of dates. `fit` solves a tuning.
//
// ## Manual verification without a reference database
//
// A printed panjika gives tithi and nakshatra, not longitudes, so `fit` has to
// work from labels. Two things make that practical:
//
// 1. **Ten dates are enough.** Spread them over at least ten years so the
//    annual bija is separable from the epoch offset; `fit` refuses to move the
//    bija below that span and says so.
// 2. **A printed tithi end time is far sharper than the tithi name.** A name
//    only says the elongation is somewhere in a 12-degree bin. The end time
//    says it is exactly `12 * n` degrees at that instant, which is a direct
//    measurement. Pass it with `--ends HH:MM` and emit the row with `--csv`.
//
// The workflow: `check` each date, keep the rows where the tithi runs well past
// sunrise (so the sunrise convention cannot flip the label), collect them into
// one CSV, run `fit`, then paste the printed `SuryaSiddhantaTuning` into
// `kSuryaSiddhantaTuning` in `surya_siddhanta_engine.dart`. `check` always uses
// that constant, so a passing `check` means the app will agree.
//
// The probe is deliberately pure Dart: it imports only the engine, never the
// Flutter/Jyotish stack, so `dart run` works. The Drik comparison lives in the
// app and in `test/surya_siddhanta_engine_test.dart`.
//
// Reference CSV for `fit`, header required. Accepted columns:
//
//   date,sun,moon      sidereal longitudes in degrees (best: fully determined)
//   date,tithi         tithi ordinal at the instant, 1..30 (as printed)
//   date,ends,tithi    "tithi n ends at date+ends" - the sharpest form
//
// `date` is an ISO date (`2026-04-14`) or an ISO instant
// (`2026-04-14T06:00:00+05:30`). A bare date is read at 06:00 local. A panjika
// labels a civil day by the tithi running *at sunrise*, so pass `--at` (or a
// full instant) with the sunrise the panjika prints rather than relying on
// 06:00.
//
// This is a developer tool. It never runs in the app.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:tithi/services/panchang/ephemeris/surya_siddhanta_engine.dart';

const String _usage = '''
Surya Siddhanta calibration probe

  dart run tool/surya_siddhanta_probe.dart check <date> [--at HH:MM]
      [--tithi <n|"Shukla Navami">] [--ends HH:MM] [--nakshatra <name>]
      [--csv]
  dart run tool/surya_siddhanta_probe.dart probe <date> [<date> ...]
  dart run tool/surya_siddhanta_probe.dart probe --range <from> <to> [--step <days>]
  dart run tool/surya_siddhanta_probe.dart fit <reference.csv> [--rows]
  dart run tool/surya_siddhanta_probe.dart verify <reference.csv> [--rows]

`check` prints what the engine says for one date, compares it with the tithi and
nakshatra you pass, and warns when the date is too close to a tithi boundary to
be a useful comparison. `--ends` additionally checks a printed tithi end time,
which is a much sharper datum than the tithi name. `--csv` also prints a row for
a `fit` reference file.

`fit` solves a tuning from a reference file and prints it ready to paste.
`--rows` also lists every reference row with its residual, which is how you find
the one date that was transcribed wrongly.

`verify` is the regression check: it measures the *shipped* tuning against a
reference file without changing it. Point it at
tool/reference/surya_siddhanta_delhi_2005_2026_yoga.csv to confirm the calibration
still holds, because yoga was held out of the fit.

Ten dates spread over ten or more years are enough to calibrate. Paste the
`SuryaSiddhantaTuning` that `fit` prints into `kSuryaSiddhantaTuning` in
lib/services/panchang/ephemeris/surya_siddhanta_engine.dart.

Dates accept `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SS+HH:MM`.
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    stdout.writeln(_usage);
    return;
  }

  switch (args.first) {
    case 'check':
      _check(args.sublist(1));
    case 'probe':
      await _probe(args.sublist(1));
    case 'fit':
      if (args.length < 2) {
        stderr.writeln('fit needs a CSV path.\n\n$_usage');
        exitCode = 64;
        return;
      }
      await _fit(args[1], showRows: args.contains('--rows'));
    case 'verify':
      if (args.length < 2) {
        stderr.writeln('verify needs a CSV path.\n\n$_usage');
        exitCode = 64;
        return;
      }
      _verify(args[1], showRows: args.contains('--rows'));
    default:
      stderr.writeln('Unknown command "${args.first}".\n\n$_usage');
      exitCode = 64;
  }
}

// --- check -----------------------------------------------------------------

const List<String> _tithiNames = [
  'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', 'Shashthi', //
  'Saptami', 'Ashtami', 'Navami', 'Dashami', 'Ekadashi', 'Dwadashi', //
  'Trayodashi', 'Chaturdashi', 'Purnima', //
  'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', 'Shashthi', //
  'Saptami', 'Ashtami', 'Navami', 'Dashami', 'Ekadashi', 'Dwadashi', //
  'Trayodashi', 'Chaturdashi', 'Amavasya', //
];

/// Name for a 1-based tithi ordinal (1 = Shukla Pratipada, 30 = Amavasya).
String _tithiName(int ordinal) {
  final paksha = ordinal <= 15 ? 'Shukla' : 'Krishna';
  return '$paksha ${_tithiNames[ordinal - 1]}';
}

/// Reads `26`, `Krishna Ekadashi`, `Ekadashi Krishna`, `Purnima`, ...
int? _parseTithiSpec(String raw) {
  final trimmed = raw.trim();
  final numeric = int.tryParse(trimmed);
  if (numeric != null) return numeric >= 1 && numeric <= 30 ? numeric : null;

  final words = trimmed
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return null;

  const aliases = <String, String>{
    'ekadasi': 'Ekadashi',
    'chaturdasi': 'Chaturdashi',
    'trayodasi': 'Trayodashi',
    'dwadasi': 'Dwadashi',
    'amawasya': 'Amavasya',
    'paurnami': 'Purnima',
    'purnima': 'Purnima',
    'amavasya': 'Amavasya',
  };

  var paksha = -1;
  String? name;
  for (final word in words) {
    if (word == 'shukla' || word == 'sukla' || word == 'waxing') {
      paksha = 0;
    } else if (word == 'krishna' || word == 'waning') {
      paksha = 1;
    } else {
      name = word;
    }
  }
  if (name == null) return null;

  final normalised =
      aliases[name] ?? name[0].toUpperCase() + name.substring(1);
  if (normalised == 'Purnima') return 15;
  if (normalised == 'Amavasya') return 30;

  final index = _tithiNames.indexOf(normalised);
  if (index < 0) return null;
  if (paksha < 0) return null; // ambiguous without a paksha
  return paksha * 15 + (index % 15 + 1);
}

void _check(List<String> args) {
  String? dateArg;
  String? at;
  String? ends;
  String? tithiSpec;
  String? nakshatraSpec;
  var wantCsv = false;

  var i = 0;
  while (i < args.length) {
    final arg = args[i];
    if (arg == '--csv') {
      wantCsv = true;
      i++;
      continue;
    }
    if (arg == '--at' || arg == '--ends' || arg == '--tithi' ||
        arg == '--nakshatra') {
      if (i + 1 >= args.length) {
        stderr.writeln('$arg needs a value.\n\n$_usage');
        exitCode = 64;
        return;
      }
      final value = args[i + 1];
      if (arg == '--at') at = value;
      if (arg == '--ends') ends = value;
      if (arg == '--tithi') tithiSpec = value;
      if (arg == '--nakshatra') nakshatraSpec = value;
      i += 2;
      continue;
    }
    if (arg.startsWith('--')) {
      stderr.writeln('Unknown option "$arg".\n\n$_usage');
      exitCode = 64;
      return;
    }
    dateArg ??= arg;
    i++;
  }

  if (dateArg == null) {
    stderr.writeln('check needs a date.\n\n$_usage');
    exitCode = 64;
    return;
  }

  final base = _parseDate(dateArg);
  var instant = at == null ? base : _withTime(base, at);

  // `check` runs the tuning the app actually ships, so a pass here means the
  // app will print the same tithi. `SuryaSiddhantaEngine` defaults to
  // `kSuryaSiddhantaTuning`.
  const engine = SuryaSiddhantaEngine();
  final ss = engine.longitudesAt(instant);
  final elongation = _norm(ss.moon - ss.sun);
  final elapsed = elongation / 12.0 + 1.0;
  final ordinal = elapsed.floor().clamp(1, 30);
  final nakPosition = _norm(ss.moon) / (360.0 / 27.0);
  final nakIndex = nakPosition.floor() % 27;

  stdout.writeln('${_format(instant)}   tuning ${engine.tuning.tag}');
  stdout.writeln(
    '  tithi        ${elapsed.toStringAsFixed(3).padLeft(7)}  '
    '${_tithiName(ordinal)}',
  );
  stdout.writeln(
    '  nakshatra    ${nakPosition.toStringAsFixed(3).padLeft(7)}  '
    '${_nakshatra(ss.moon)} ($nakIndex)',
  );
  final yogaPosition = _norm(ss.sun + ss.moon) / (360.0 / 27.0);
  final yogaIndex = yogaPosition.floor() % 27;
  stdout.writeln(
    '  yoga         ${yogaPosition.toStringAsFixed(3).padLeft(7)}  '
    '${_yoga(ss.sun + ss.moon)} (${yogaIndex + 1})',
  );
  stdout.writeln(
    '  sun ${ss.sun.toStringAsFixed(3)}   '
    'moon ${ss.moon.toStringAsFixed(3)}   '
    'elongation ${elongation.toStringAsFixed(3)}',
  );

  var matches = 0;
  var comparisons = 0;

  if (tithiSpec != null) {
    comparisons++;
    final expected = _parseTithiSpec(tithiSpec);
    if (expected == null) {
      stdout.writeln('  expected     "$tithiSpec" is not a tithi I can read');
    } else {
      final ok = expected == ordinal;
      if (ok) matches++;
      stdout.writeln(
        '  expected     ${_tithiName(expected)} ($expected) -> '
        '${ok ? 'MATCH' : 'MISMATCH, engine says ${_tithiName(ordinal)}'}',
      );
    }
  }

  if (nakshatraSpec != null) {
    comparisons++;
    final ok =
        nakshatraSpec.trim().toLowerCase() ==
        _nakshatra(ss.moon).toLowerCase();
    if (ok) matches++;
    stdout.writeln(
      '  expected     ${nakshatraSpec.trim()} -> '
      '${ok ? 'MATCH' : 'MISMATCH, engine says ${_nakshatra(ss.moon)}'}',
    );
  }

  // The printed end time is the sharpest datum a panjika offers: at that
  // instant the elongation should be exactly 12 * n degrees.
  final expectedOrdinal = tithiSpec == null
      ? null
      : _parseTithiSpec(tithiSpec);
  if (ends != null && expectedOrdinal != null) {
    final endInstant = _withTime(base, ends);
    final endSs = engine.longitudesAt(endInstant);
    final endElongation = _norm(endSs.moon - endSs.sun);
    final target = 12.0 * expectedOrdinal;
    final residual = _signed(endElongation - target);
    stdout.writeln(
      '  tithi end    printed $ends -> elongation '
      '${endElongation.toStringAsFixed(3)} vs $target -> '
      '${residual.toStringAsFixed(2)} deg off',
    );
  }

  final tithiFraction = elapsed - elapsed.floor();
  final tithiDistance = math.min(tithiFraction, 1 - tithiFraction);
  final tithiHours = tithiDistance * 12.0 / 12.1907 * 24.0;
  final nakFraction = nakPosition - nakPosition.floor();
  final nakDistance = math.min(nakFraction, 1 - nakFraction);
  final nakHours = nakDistance * (360.0 / 27.0) / 13.1764 * 24.0;

  stdout.writeln(
    '  margin       tithi changes in ~${tithiHours.toStringAsFixed(1)} h, '
    'nakshatra in ~${nakHours.toStringAsFixed(1)} h',
  );
  if (tithiDistance < 0.15 || nakDistance < 0.15) {
    stdout.writeln(
      '  note         close to a boundary: a model error of ~0.1 tithi can '
      'flip the name here, so this date is a weak check.',
    );
  }

  if (comparisons > 0) {
    stdout.writeln('  result       $matches/$comparisons matched');
  }

  if (wantCsv) {
    final dateText = instant.toIso8601String().substring(0, 10);
    if (expectedOrdinal == null) {
      stdout.writeln('  (pass --tithi to emit a reference row)');
    } else if (ends != null) {
      stdout.writeln();
      stdout.writeln('date,ends,tithi');
      stdout.writeln('$dateText,$ends,$expectedOrdinal');
    } else {
      stdout.writeln();
      stdout.writeln('date,tithi');
      stdout.writeln('$dateText,${expectedOrdinal.toStringAsFixed(1)}');
    }
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

Future<void> _fit(String path, {bool showRows = false}) async {
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
      '`date,sun,moon`, `date,tithi` or `date,ends,tithi`.',
    );
    exitCode = 65;
    return;
  }

  final mode = _modeOf(rows);
  stdout.writeln('Fitting ${rows.length} reference rows ($mode).');

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

  // Whether the *absolute* frame is observable, which decides if the Sun's
  // epoch may move.
  //
  // Tithi sees only Moon-minus-Sun, so adding the same offset to both epochs
  // changes no tithi: a tithi-only file leaves that direction null and the
  // ridge term resolves it arbitrarily, walking the fit hundreds of degrees
  // from the text. Nakshatra end times see the Moon absolutely, and yoga end
  // times see the Sun and Moon together - either of those, paired with tithi,
  // pins both bodies.
  final hasLongitudes = rows.any((r) => r.hasLongitudes);
  final hasTithiEnd = rows.any((r) => r.end?.limb == _Limb.tithi);
  final hasNakshatraEnd = rows.any((r) => r.end?.limb == _Limb.nakshatra);
  final hasYogaEnd = rows.any((r) => r.end?.limb == _Limb.yoga);
  final allowSun =
      hasLongitudes || hasYogaEnd || (hasNakshatraEnd && hasTithiEnd);

  if (!allowBija) {
    stdout.writeln(
      'Note: references span only ${spanYears.toStringAsFixed(1)} years, so '
      'only the epoch offset is fitted. Supply dates spanning at least '
      '${minSpanYearsForBija.toInt()}+ years to calibrate the annual bija.',
    );
  }
  if (!allowSun) {
    stdout.writeln(
      'Note: nothing in this file pins the absolute frame, so the Sun epoch '
      'stays at the classical value and the Moon absorbs the whole offset. '
      'Tithi will fit; nakshatra, yoga and masa cannot be calibrated without '
      'nakshatra or yoga end times.',
    );
  }

  // Gauss-Newton cannot be trusted to find the lunar apogee on its own.
  //
  // The apogee longitude enters through the manda correction, so the residual
  // is periodic in it with a ~5-degree amplitude: the linearised step wants to
  // jump tens of degrees at once, gets clamped, and the damping then accepts a
  // tiny step that improves the sum of squares by almost nothing. The solve
  // stops a long way from the right phase and reports a residual that looks
  // like the model's ceiling when it is really the solver's.
  //
  // So: start from every 15 degrees of apogee and keep the best landing. This
  // is cheap (the solve is deterministic and short) and it also measures the
  // floor honestly, because one of the starts is always within 7.5 degrees of
  // the optimum phase.
  var tuning = SuryaSiddhantaTuning.classical;
  var bestRms = _rms(_residualVector(rows, tuning));
  var bestStart = 0.0;
  var starts = 1;

  for (var start = 15; start < 360; start += 15) {
    var candidate = SuryaSiddhantaTuning.classical.copyWith(
      moonApsisEpochLongitude: start.toDouble(),
    );
    for (var iteration = 0; iteration < 60; iteration++) {
      final fitted = _fitOnce(
        rows,
        candidate,
        allowBija: allowBija,
        allowSun: allowSun,
      );
      final moved = _maxAbsDelta(candidate, fitted);
      candidate = fitted;
      if (moved < 1e-10) break;
    }
    starts++;
    final rms = _rms(_residualVector(rows, candidate));
    if (rms < bestRms) {
      bestRms = rms;
      bestStart = start.toDouble();
      tuning = candidate;
    }
  }

  stdout.writeln(
    'Searched $starts apogee starting points; best from '
    '${bestStart.toStringAsFixed(0)} deg (rms '
    '${bestRms.toStringAsFixed(3)} deg).',
  );

  final engine = SuryaSiddhantaEngine(tuning: tuning);
  final groups = _residualGroups(rows, engine);

  stdout.writeln();
  stdout.writeln('Fitted tuning:');
  stdout.writeln(_tuningSnippet(tuning));
  stdout.writeln();

  if (showRows) _printRows(rows, engine, outlierAbove: 0.5);

  stdout.writeln('Residuals (degrees unless noted):');
  for (final group in groups) {
    final unit = group.label == 'tithi (bin)' ? ' tithi' : ' deg';
    stdout.writeln(
      '  ${group.label.padRight(14)} n=${group.count.toString().padLeft(2)} '
      'max ${group.max.toStringAsFixed(3).padLeft(7)}$unit '
      'rms ${group.rms.toStringAsFixed(3).padLeft(7)}$unit',
    );
  }
  if (groups.any((g) => g.label.endsWith('end'))) {
    stdout.writeln(
      '  (a printed boundary time is only as good as the panjika rounds it, '
      'usually a minute or two - about 0.03 deg)',
    );
  }

  // A boundary time is a point measurement, so anything past ~0.5 deg means
  // the model, not the rounding, is off. A tithi *bin* is a whole 12 deg wide,
  // so half a tithi there is expected and harmless.
  final poorFit = groups.any(
    (g) => g.label != 'tithi (bin)' && g.max > 0.5,
  );
  if (poorFit) {
    stdout.writeln(
      'A boundary residual above ~0.5 deg means the reference rows cannot be '
      'matched by epoch offset + linear bija alone. Check the panjika '
      'convention (sunrise vs midnight labelling, or an end time printed for '
      'the next day) before tightening the model.',
    );
  }
  if (_hitsBound(tuning)) {
    stdout.writeln(
      'WARNING: at least one parameter stopped at its limit, so this is not a '
      'physical solution. Do not paste it - the reference rows disagree with '
      'each other or with the engine. Re-check the dates with `check` first.',
    );
  }
}

/// One line per reference row, with the signed residual the engine leaves.
void _printRows(
  List<_ReferenceRow> rows,
  SuryaSiddhantaEngine engine, {
  required double outlierAbove,
}) {
  stdout.writeln('Rows:');
  for (final row in rows) {
    final ahargana = SuryaSiddhantaEngine.aharganaAt(row.instant);
    final String what;
    final double residual;
    if (row.hasLongitudes) {
      what = 'sun/moon';
      residual = math.max(
        _signed(row.sun! - engine.trueSunLongitude(ahargana)).abs(),
        _signed(row.moon! - engine.trueMoonLongitude(ahargana)).abs(),
      );
    } else if (row.end != null) {
      what = '${row.end!.limb.label} ${row.end!.ordinal}';
      residual = _limbResidual(engine, ahargana, row.end!);
    } else {
      what = 'tithi bin ${row.tithi}';
      residual = _signed(
        row.tithi! -
            _tithi(
              engine.trueMoonLongitude(ahargana) -
                  engine.trueSunLongitude(ahargana),
            ),
      );
    }
    final flag = residual.abs() > outlierAbove ? '  <-- outlier' : '';
    stdout.writeln(
      '  ${_format(row.instant).substring(0, 16)} '
      '${what.padRight(14)} residual '
      '${residual.toStringAsFixed(2).padLeft(7)}$flag',
    );
  }
  stdout.writeln();
}

/// Measures the *shipped* tuning against a reference file, without fitting.
///
/// This is the regression half of the workflow. `fit` finds a tuning; `verify`
/// answers "does the tuning the app ships still reproduce the reference file?".
/// Point it at a file that was held out of the fit (the yoga boundaries) and a
/// small residual means the calibration is intact.
///
/// The pass threshold is 0.01 degrees. That is the resolution of the reference
/// times themselves: a minute of tithi or yoga time is about 0.01 degrees, so
/// asking for better than that would be asking to beat the panjika's rounding.
void _verify(String path, {bool showRows = false}) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No such file: $path');
    exitCode = 66;
    return;
  }

  final rows = _readReferenceCsv(file.readAsLinesSync());
  if (rows.isEmpty) {
    stderr.writeln('No usable rows in $path.');
    exitCode = 65;
    return;
  }

  const engine = SuryaSiddhantaEngine();
  const limit = 0.01;

  stdout.writeln(
    'Verifying the shipped tuning against ${rows.length} reference rows '
    '(${_modeOf(rows)}).',
  );

  if (showRows) _printRows(rows, engine, outlierAbove: limit);

  final groups = _residualGroups(rows, engine);
  var worst = 0.0;
  for (final group in groups) {
    worst = math.max(worst, group.max);
    final unit = group.label == 'tithi (bin)' ? ' tithi' : ' deg';
    stdout.writeln(
      '  ${group.label.padRight(14)} n=${group.count.toString().padLeft(2)} '
      'max ${group.max.toStringAsFixed(4).padLeft(8)}$unit '
      'rms ${group.rms.toStringAsFixed(4).padLeft(8)}$unit',
    );
  }

  if (worst <= limit) {
    stdout.writeln(
      'PASS - every row is inside the source\'s own rounding '
      '(${limit.toStringAsFixed(2)} deg).',
    );
    return;
  }

  stdout.writeln(
    'FAIL - worst residual ${worst.toStringAsFixed(3)} deg exceeds '
    '${limit.toStringAsFixed(2)} deg. Either kSuryaSiddhantaTuning changed or '
    'the engine did. Re-run `fit` on the tithi/nakshatra file and compare.',
  );
  exitCode = 1;
}

/// Human-readable description of the row kinds present in a reference file.
String _modeOf(List<_ReferenceRow> rows) {
  final kinds = <String>[
    if (rows.any((r) => r.hasLongitudes)) 'longitudes',
    for (final limb in _Limb.values)
      if (rows.any((r) => r.end?.limb == limb)) '${limb.label} ends',
    if (rows.any((r) => r.tithi != null)) 'tithi',
  ];
  return kinds.isEmpty ? 'tithi' : kinds.join(' + ');
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

/// Slots that set the Sun's absolute longitude.
bool _isSunSlot(int slot) => slot == _kSunEpoch || slot == _kSunBija;

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
/// a few passes. The step is damped: a reference file the model cannot match
/// (a mislabelled row, the wrong sunrise convention) would otherwise send the
/// parameters off to infinity instead of reporting a poor fit. Halving the step
/// until the residual stops growing keeps the result bounded and makes the
/// reported residual the honest one.
SuryaSiddhantaTuning _fitOnce(
  List<_ReferenceRow> rows,
  SuryaSiddhantaTuning tuning, {
  required bool allowBija,
  required bool allowSun,
}) {
  final params = _paramsOf(tuning);
  final residual = _residualVector(rows, tuning);
  final jacobian = _numericJacobian(
    rows,
    params,
    allowBija: allowBija,
    allowSun: allowSun,
  );

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

  final baseRms = _rms(residual);
  var scale = 1.0;
  for (var attempt = 0; attempt < 12; attempt++) {
    final next = List<double>.from(params);
    for (var i = 0; i < n; i++) {
      if (!allowBija && _isBija(i)) continue;
      if (!allowSun && _isSunSlot(i)) continue;
      next[i] += step[i] * scale;
    }
    final candidate = _tuningOf(_clampParams(next));
    if (_rms(_residualVector(rows, candidate)) <= baseRms) return candidate;
    scale *= 0.5;
  }
  // No step in this direction improves the fit: report the current tuning and
  // let the caller print the residual it actually achieves.
  return tuning;
}

double _rms(List<double> values) {
  if (values.isEmpty) return 0.0;
  var sum = 0.0;
  for (final value in values) {
    sum += value * value;
  }
  return math.sqrt(sum / values.length);
}

/// Keeps the solve inside the region where the parameters still mean what the
/// text says they mean.
///
/// An epoch longitude is a longitude, so any offset beyond half a turn is the
/// same tuning under a different name; an annual bija is a few tens of arc
/// seconds at most. Without these bounds a reference file the model cannot
/// match walks the phase to an unrelated point on the periodic residual
/// surface, where the RMS is marginally lower for no physical reason.
List<double> _clampParams(List<double> v) {
  const epochBounds = 180.0;
  const bijaBounds = 60.0; // arc seconds per year
  return [
    for (var i = 0; i < v.length; i++)
      v[i].clamp(
        _isBija(i) ? -bijaBounds : -epochBounds,
        _isBija(i) ? bijaBounds : epochBounds,
      ),
  ];
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
    final elongation = _norm(
      engine.trueMoonLongitude(ahargana) - engine.trueSunLongitude(ahargana),
    );

    // A printed limb boundary is a direct measurement: at that instant the
    // limb's function of the longitudes equals `degreesPer * ordinal`.
    if (row.end != null) {
      out.add(_limbResidual(engine, ahargana, row.end!));
      continue;
    }

    final ssTithi = _tithi(elongation);
    out.add(_signed(row.tithi! - ssTithi) * 12.0);
  }

  return out;
}

/// Signed error in degrees at a printed limb boundary.
double _limbResidual(
  SuryaSiddhantaEngine engine,
  double ahargana,
  _LimbEnd end,
) {
  final sun = engine.trueSunLongitude(ahargana);
  final moon = engine.trueMoonLongitude(ahargana);
  final target = end.limb.degreesPer * end.ordinal;

  final measured = switch (end.limb) {
    _Limb.tithi => _norm(moon - sun),
    _Limb.nakshatra => _norm(moon),
    _Limb.yoga => _norm(sun + moon),
  };
  return _signed(measured - target);
}

/// Finite-difference Jacobian, `J[row][parameter]`.
List<List<double>> _numericJacobian(
  List<_ReferenceRow> rows,
  List<double> params, {
  required bool allowBija,
  required bool allowSun,
}) {
  // Degrees for the longitudes, arc seconds for the annual rates: a single
  // step size would be either lost to cancellation or outside the linear
  // regime for the other parameter type.
  const steps = [1e-4, 1e-2, 1e-4, 1e-2, 1e-4, 1e-2];

  final base = _residualVector(rows, _tuningOf(params));
  final columns = List.generate(params.length, (_) => <double>[]);

  for (var i = 0; i < params.length; i++) {
    final frozen =
        (!allowBija && _isBija(i)) || (!allowSun && _isSunSlot(i));
    if (frozen) {
      columns[i] = List<double>.filled(base.length, 0.0);
      continue;
    }
    final step = steps[i];
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

/// Residuals split by the limb that produced them.
///
/// A file that mixes limbs has residuals in different units (tithi for a
/// tithi-bin row, degrees for every end time), so one blended number would be
/// meaningless. Reporting per limb also shows *which* limb is not fitting,
/// which is the useful signal when calibrating.
typedef _ResidualGroup = ({String label, double max, double rms, int count});

List<_ResidualGroup> _residualGroups(
  List<_ReferenceRow> rows,
  SuryaSiddhantaEngine engine,
) {
  final buckets = <String, List<double>>{};

  for (final row in rows) {
    final ahargana = SuryaSiddhantaEngine.aharganaAt(row.instant);
    final String label;
    final double residual;

    if (row.hasLongitudes) {
      label = 'longitudes';
      final sun = _signed(row.sun! - engine.trueSunLongitude(ahargana));
      final moon = _signed(row.moon! - engine.trueMoonLongitude(ahargana));
      residual = math.max(sun.abs(), moon.abs());
    } else if (row.end != null) {
      label = '${row.end!.limb.label} end';
      residual = _limbResidual(engine, ahargana, row.end!);
    } else {
      label = 'tithi (bin)';
      final elongation = _norm(
        engine.trueMoonLongitude(ahargana) - engine.trueSunLongitude(ahargana),
      );
      residual = _signed(row.tithi! - _tithi(elongation));
    }

    buckets.putIfAbsent(label, () => <double>[]).add(residual);
  }

  return [
    for (final entry in buckets.entries)
      (
        label: entry.key,
        max: entry.value.map((v) => v.abs()).reduce(math.max),
        rms: math.sqrt(
          entry.value.map((v) => v * v).reduce((a, b) => a + b) /
              entry.value.length,
        ),
        count: entry.value.length,
      ),
  ]..sort((a, b) => a.label.compareTo(b.label));
}

/// True when a fitted parameter sits on the clamp limit, i.e. the solve wanted
/// to leave the physically meaningful region.
bool _hitsBound(SuryaSiddhantaTuning tuning) {
  final params = _paramsOf(tuning);
  for (var i = 0; i < params.length; i++) {
    final limit = _isBija(i) ? 60.0 : 180.0;
    if ((params[i].abs() - limit).abs() < 1e-6) return true;
  }
  return false;
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

/// A Panchang limb whose boundary time a panjika prints.
///
/// Each one is a linear function of the two longitudes, which is what makes
/// them usable as calibration constraints:
///
/// - tithi: `moon - sun`, 12 degrees per tithi
/// - nakshatra: `moon`, 13 deg 20 min per mansion
/// - yoga: `sun + moon`, 13 deg 20 min per yoga
///
/// Nakshatra is the only one of the three that sees the Moon *absolutely*, and
/// yoga the only one that sees the Sun, which is why a tithi-only file cannot
/// calibrate either of them.
enum _Limb {
  tithi('tithi', 12.0, 30),
  nakshatra('nakshatra', 360.0 / 27.0, 27),
  yoga('yoga', 360.0 / 27.0, 27);

  const _Limb(this.label, this.degreesPer, this.count);

  final String label;
  final double degreesPer;
  final int count;
}

/// The Panchang limb that ends at [instant], and its 1-based ordinal.
typedef _LimbEnd = ({_Limb limb, int ordinal});

class _ReferenceRow {
  _ReferenceRow({
    required this.instant,
    this.sun,
    this.moon,
    this.tithi,
    this.end,
  });

  final DateTime instant;
  final double? sun;
  final double? moon;

  /// Tithi ordinal at [instant], 1..30. A panjika prints only the ordinal, so
  /// this pins the tithi to a one-tithi-wide bin.
  final double? tithi;

  /// Limb boundary at [instant]. At that moment the limb's function of the
  /// longitudes equals `degreesPer * ordinal` exactly - a direct measurement,
  /// unlike [tithi].
  final _LimbEnd? end;

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
    final endsCell = cell('ends');
    final limbCell = cell('limb');
    final ordinalCell = cell('ordinal');

    final base = _parseDate(dateCell);

    // `date,ends,limb,ordinal` reads as "limb <ordinal> ends at date+ends".
    // This is the form that can carry nakshatra and yoga, which is what makes
    // an absolute-frame calibration possible.
    if (endsCell != null && limbCell != null) {
      final limb = _limbFromName(limbCell);
      if (limb == null) {
        stderr.writeln('Unknown `limb` "$limbCell" (expected tithi, '
            'nakshatra or yoga): $line');
        continue;
      }
      final ordinal = _parseOrdinal(limb, ordinalCell);
      if (ordinal == null) {
        stderr.writeln(
          'Row has no usable ${limb.label} ordinal in `ordinal`: $line',
        );
        continue;
      }
      final endInstant = _withTimeOrNull(base, endsCell);
      if (endInstant == null) {
        stderr.writeln('Ignoring row with an unreadable `ends` value: $line');
        continue;
      }
      rows.add(
        _ReferenceRow(
          instant: endInstant,
          end: (limb: limb, ordinal: ordinal),
        ),
      );
      continue;
    }

    // `date,ends,tithi` is the shorthand for a tithi end.
    if (endsCell != null) {
      final ordinal = int.tryParse(cell('tithi') ?? '');
      // An `ends` cell without a whole-number ordinal used to fall through and
      // silently become a plain sunrise row, discarding the end time - the one
      // datum that makes the row useful. Refuse it instead.
      if (ordinal == null) {
        stderr.writeln(
          'Row has an `ends` time but no whole-number `tithi` ordinal '
          '(write `26`, not `26.0`; or use `limb`/`ordinal`): $line',
        );
        continue;
      }
      final endInstant = _withTimeOrNull(base, endsCell);
      if (endInstant == null) {
        stderr.writeln('Ignoring row with an unreadable `ends` value: $line');
        continue;
      }
      rows.add(
        _ReferenceRow(
          instant: endInstant,
          end: (limb: _Limb.tithi, ordinal: ordinal),
        ),
      );
      continue;
    }

    if (sun == null && moon == null && tithi == null) continue;

    rows.add(
      _ReferenceRow(
        instant: base,
        sun: sun,
        moon: moon,
        tithi: tithi,
      ),
    );
  }

  return rows;
}

/// Nakshatra names, 1-based, in order.
const List<String> _nakshatraNames = [
  'Ashvini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra',
  'Punarvasu', 'Pushya', 'Ashlesha', 'Magha', 'PurvaPhalguni',
  'UttaraPhalguni', 'Hasta', 'Chitra', 'Svati', 'Vishakha', 'Anuradha',
  'Jyeshtha', 'Mula', 'PurvaShadha', 'UttaraShadha', 'Shravana',
  'Dhanishta', 'Shatabhisha', 'PurvaBhadrapada', 'UttaraBhadrapada',
  'Revati',
];

/// Yoga names, 1-based, in order.
const List<String> _yogaNames = [
  'Vishkambha', 'Priti', 'Ayushman', 'Saubhagya', 'Shobhana', 'Atiganda',
  'Sukarma', 'Dhriti', 'Shula', 'Ganda', 'Vriddhi', 'Dhruva', 'Vyaghata',
  'Harshana', 'Vajra', 'Siddhi', 'Vyatipata', 'Variyana', 'Parigha', 'Shiva',
  'Siddha', 'Sadhya', 'Shubha', 'Shukla', 'Brahma', 'Indra', 'Vaidhriti',
];

_Limb? _limbFromName(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'tithi' => _Limb.tithi,
    'nakshatra' || 'nakshatram' || 'star' => _Limb.nakshatra,
    'yoga' || 'yogam' => _Limb.yoga,
    _ => null,
  };
}

/// Parses an `ordinal` cell: a plain number, or the limb's traditional name.
///
/// Names are accepted because that is what a panjika prints. Anything that does
/// not resolve is rejected rather than guessed - a wrong ordinal is a 12-degree
/// error that would silently corrupt the fit.
int? _parseOrdinal(_Limb limb, String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final numeric = int.tryParse(trimmed);
  if (numeric != null) {
    return numeric >= 1 && numeric <= limb.count ? numeric : null;
  }

  return switch (limb) {
    _Limb.tithi => _parseTithiSpec(trimmed),
    _Limb.nakshatra => _lookupLoose(_nakshatraNames, trimmed),
    _Limb.yoga => _lookupLoose(_yogaNames, trimmed),
  };
}

/// Name lookup that tolerates case, spacing and the usual transliteration
/// variants (`Purva Phalguni`, `PurvaPhalguni`, `Pushy.`).
int? _lookupLoose(List<String> names, String raw) {
  String fold(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  final needle = fold(raw);
  if (needle.isEmpty) return null;
  for (var i = 0; i < names.length; i++) {
    if (fold(names[i]) == needle) return i + 1;
  }
  // A panjika may abbreviate ("Pushy." for Pushya) or add a suffix; accept a
  // unique prefix match, but never an ambiguous one.
  final prefix = <int>[
    for (var i = 0; i < names.length; i++)
      if (fold(names[i]).startsWith(needle) ||
          needle.startsWith(fold(names[i])))
        i + 1,
  ];
  return prefix.length == 1 ? prefix.single : null;
}

// --- small helpers ---------------------------------------------------------

/// Panjika times are India Standard Time. Dart has no fixed-offset DateTime,
/// so instants are kept as real UTC and IST wall clock is converted explicitly:
/// relying on the machine's local zone would silently shift every reference by
/// hours (and therefore degrees) on a developer machine outside India.
const Duration _istOffset = Duration(hours: 5, minutes: 30);

/// IST wall clock for [instant].
DateTime _istWall(DateTime instant) => instant.toUtc().add(_istOffset);

/// Real instant for [hour]:[minute] IST on the IST calendar day of [base].
DateTime _withTime(DateTime base, String hhmm) {
  final parts = hhmm.split(':');
  final wall = _istWall(base);
  return DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  ).subtract(_istOffset);
}

DateTime? _withTimeOrNull(DateTime base, String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return _withTime(base, hhmm);
}

DateTime _parseDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    stderr.writeln('Cannot parse date "$raw". Use YYYY-MM-DD or an ISO instant.');
    exitCode = 64;
    return DateTime.utc(2000);
  }
  // A bare calendar date is read at 06:00 IST, which is after sunrise for
  // India and matches how a panjika labels a civil day.
  if (!raw.contains('T')) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      6,
    ).subtract(_istOffset);
  }
  return parsed.toUtc();
}

/// Elapsed tithi in 1..30.
double _tithi(double moonMinusSun) => _norm(moonMinusSun) / 12.0 + 1.0;

String _nakshatra(double moonLongitude) =>
    _nakshatraNames[(_norm(moonLongitude) / (360.0 / 27.0)).floor() % 27];

String _yoga(double sunPlusMoon) =>
    _yogaNames[(_norm(sunPlusMoon) / (360.0 / 27.0)).floor() % 27];

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
  final wall = _istWall(instant);
  return '${wall.year}-${two(wall.month)}-${two(wall.day)} '
      '${two(wall.hour)}:${two(wall.minute)} +05:30';
}
