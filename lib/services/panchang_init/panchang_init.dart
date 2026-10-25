import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show FlutterError, TargetPlatform;
import 'package:flutter/services.dart' show AssetBundle;
import 'package:jyotish/jyotish.dart' show EphemerisDataRange;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Swiss Ephemeris data files the panchang engine reads at runtime.
///
/// The names are the ones Swiss Ephemeris itself expects: `sepl`, `semo` and
/// `seas` are the planetary, lunar and main-asteroid files, and the `_18`
/// suffix selects the 1800-2399 CE range. Adding a file here means it must
/// also exist under `assets/ephe/` and be declared in `pubspec.yaml`.
const List<String> kEphemerisAssets = <String>[
  'seas_18.se1',
  'semo_18.se1',
  'sepl_18.se1',
];

/// Asset folder the files are loaded from.
const String _assetDirectory = 'assets/ephe';

/// SHA-256 of each bundled `.se1` file, as shipped in [kEphemerisAssets].
///
/// Size and the `SWISSEPH` header cannot tell a truncated file from a complete
/// one once the cut lands past the header, and cannot tell this build's
/// ephemeris from another. This map is the build manifest: the installer checks
/// the asset before copying it and the installed copy on every launch.
///
/// `test/panchang_init_test.dart` recomputes these hashes from `assets/ephe/`,
/// so replacing a data file without updating the manifest fails the suite.
const Map<String, String> kEphemerisAssetSha256 = {
  'seas_18.se1':
      '5fd9c2aa1654e37c09a6aeb558076e795409b7dc4bd948ebc0faa7d4a7686b5b',
  'semo_18.se1':
      'ecfa54dbf5bc0b5a9bc3e04ed28629a821e98625eacae38f4070593bba0e2980',
  'sepl_18.se1':
      '0b7e416e3c1be9e6a0dd1d711dae7f7685793a0e7df13f76363a493dc27b6ea1',
};

/// Every Swiss Ephemeris `.se1` file starts with the ASCII header
/// `SWISSEPH  1\r\n`. Only the first word is checked: the digit is a file
/// format version, and a future format bump should not be mistaken for a
/// corrupt file.
final Uint8List _se1Magic = Uint8List.fromList('SWISSEPH'.codeUnits);

/// Smallest plausible `.se1` file. The bundled trio is 223 KB-1.3 MB; anything
/// under a kilobyte is a truncated copy or a stray placeholder, not data Swiss
/// Ephemeris can read.
const int _minSe1Bytes = 1024;

/// An init failure whose [message] is written for the user, not the developer.
///
/// The error banner surfaces [message] verbatim, so a subclass must not expose
/// raw FFI or filesystem text.
abstract interface class PanchangInitException implements Exception {
  String get message;
}

/// Raised when the bundled ephemeris data cannot be installed.
///
/// [message] is written for the user, not the developer: it names the file and
/// the recovery step, because on a device the only available action is to
/// reinstall. Callers surface it verbatim instead of inventing their own copy.
class EphemerisAssetException implements PanchangInitException {
  const EphemerisAssetException(this.message, {this.file, this.cause});

  /// User-facing explanation of what failed and what to do about it.
  @override
  final String message;

  /// Name of the offending `.se1` file, when one can be identified.
  final String? file;

  /// Underlying error, kept for logs and tests.
  final Object? cause;

  @override
  String toString() =>
      'EphemerisAssetException${file == null ? '' : '($file)'}: $message';
}

/// Raised when the native rise/set engine could not be installed.
///
/// The pure-Dart fallbacks are 1-3 minutes out, which is enough to move a
/// `moonrise` observance's matching instant, so a platform that ships the
/// native engine must not silently run on them.
class EphemerisEngineException implements PanchangInitException {
  const EphemerisEngineException(this.message, {this.cause});

  /// User-facing explanation of what failed and what to do about it.
  @override
  final String message;

  /// Underlying setup error, kept for logs and tests.
  final Object? cause;

  @override
  String toString() => 'EphemerisEngineException: $message';
}

/// Platforms that ship the native engine and must never run on a fallback.
///
/// `packages/jyotish` builds Swiss Ephemeris for Android only; the other
/// platforms are scaffolding that intentionally use the labelled
/// approximations, so a fallback there is the documented behaviour rather than
/// a failure.
const Set<TargetPlatform> kNativeEnginePlatforms = {TargetPlatform.android};

/// Years the bundled `.se1` files must cover.
///
/// This is an application policy, not a package default: `packages/jyotish`
/// reports whatever range actually loaded and never hardcodes an asset range.
const int kEphemerisExpectedStartYear = 1800;
const int kEphemerisExpectedEndYear = 2399;

/// Throws [EphemerisEngineException] when [platform] requires the native engine
/// but it could not be installed.
///
/// [solarSetupError] and [moonSetupError] are the errors recorded by
/// `SolarEventsService.configureSwiss` and
/// `MoonEventsService.configureSwiss`. Either one non-null means the app would
/// otherwise present approximate sunrise, sunset or moonrise as real - and the
/// moonrise instant is a festival matching checkpoint, so the approximation
/// would reach observance assignment.
void ensureNativeEngineInstalled({
  required TargetPlatform platform,
  required Object? solarSetupError,
  required Object? moonSetupError,
}) {
  if (!kNativeEnginePlatforms.contains(platform)) return;
  if (solarSetupError == null && moonSetupError == null) return;
  throw EphemerisEngineException(
    'Tithi could not start its calculation engine on this device: the native '
    'Swiss Ephemeris library did not load, so sunrise, sunset and moonrise '
    'would be approximate. Reinstall the app to restore it. If you build Tithi '
    "from source, make sure the library is built for this device's CPU.",
    cause: solarSetupError ?? moonSetupError,
  );
}

/// Throws [EphemerisAssetException] when the loaded files do not cover the
/// years Tithi promises.
///
/// A file can be present but still not be the 1800-2399 asset, and a missing
/// file makes Swiss Ephemeris fall back to Moshier without failing. Checking
/// the range the library actually loaded is the only way to tell the two apart
/// after startup.
void ensureEphemerisRangeInstalled(EphemerisDataRange range) {
  if (range.coversYears(
    kEphemerisExpectedStartYear,
    kEphemerisExpectedEndYear,
  )) {
    return;
  }

  final missing = <String>[
    if (range.planets == null) 'planetary (sepl_18.se1)',
    if (range.moon == null) 'lunar (semo_18.se1)',
  ];
  final detail = missing.isEmpty
      ? 'The loaded files do not cover '
            '$kEphemerisExpectedStartYear-$kEphemerisExpectedEndYear CE.'
      : 'The ${missing.join(' and ')} ephemeris data did not load.';

  throw EphemerisAssetException(
    'Tithi could not verify its '
    '$kEphemerisExpectedStartYear-$kEphemerisExpectedEndYear ephemeris data. '
    '$detail Reinstall the app to restore the bundled files. If you build '
    'Tithi from source, make sure assets/ephe contains sepl_18.se1 and '
    'semo_18.se1.',
    file: range.planets == null
        ? 'sepl_18.se1'
        : range.moon == null
        ? 'semo_18.se1'
        : null,
  );
}

/// Copies the bundled ephemeris files to the app's documents directory.
///
/// Returns the directory Swiss Ephemeris should be pointed at.
///
/// A file is copied only when the installed copy is missing or fails
/// verification (size + `SWISSEPH` header + SHA-256 from [sha256ByFile]). The
/// old "exists, so keep it" check trusted a copy that a killed first launch or
/// a corrupt install could have left truncated, and Swiss Ephemeris then failed
/// later with an opaque `swe_calc` error far from the cause.
///
/// [sha256ByFile] is a parameter rather than a direct read of
/// [kEphemerisAssetSha256] so tests can install synthetic bytes; production
/// callers use the default.
Future<String> copyEphemerisFiles(
  AssetBundle bundle, {
  Map<String, String> sha256ByFile = kEphemerisAssetSha256,
}) async {
  final appDir = await getApplicationDocumentsDirectory();
  final epheDir = Directory(p.join(appDir.path, 'ephe'));

  try {
    if (!await epheDir.exists()) {
      await epheDir.create(recursive: true);
    }
  } on FileSystemException catch (error) {
    throw EphemerisAssetException(
      'Could not create the folder Tithi keeps its ephemeris data in '
      '(${epheDir.path}). Free up storage space in the app\'s documents '
      'directory and reopen Tithi.',
      cause: error,
    );
  }

  for (final name in kEphemerisAssets) {
    final expected = sha256ByFile[name];
    if (expected == null) {
      // Unreachable while kEphemerisAssets and kEphemerisAssetSha256 are in
      // sync (a test enforces that). Fail loudly instead of silently skipping
      // verification if someone adds a file to only one of them.
      throw EphemerisAssetException(
        'Tithi has no checksum for its "$name" ephemeris file, so the install '
        'cannot be verified. This is a build configuration error: add $name to '
        'kEphemerisAssetSha256 in lib/services/panchang_init/panchang_init.dart.',
        file: name,
      );
    }

    final target = File(p.join(epheDir.path, name));
    if (await _invalidReason(target, expectedSha256: expected) == null) {
      continue;
    }

    final bytes = await _readAsset(bundle, name);
    final assetProblem = _invalidBytesReason(bytes, expectedSha256: expected);
    if (assetProblem != null) {
      throw EphemerisAssetException(
        'The Swiss Ephemeris file "$name" bundled with the app is not usable '
        '($assetProblem). Reinstall the app to restore it. If you are building '
        'from source, put a valid $name in $_assetDirectory/ and rebuild.',
        file: name,
      );
    }

    await _writeAtomically(target, bytes, expectedSha256: expected);
  }

  return epheDir.path;
}

/// Loads `assets/ephe/[name]` and translates a missing asset into an
/// actionable error instead of a bare `Unable to load asset` from Flutter.
Future<Uint8List> _readAsset(AssetBundle bundle, String name) async {
  final key = '$_assetDirectory/$name';
  final ByteData data;
  try {
    data = await bundle.load(key);
  } on FlutterError catch (error) {
    throw EphemerisAssetException(
      'The Swiss Ephemeris file "$name" is missing from the app bundle '
      '(looked for "$key"). Tithi cannot calculate the panchang without it. '
      'Reinstall the app to restore the bundled data. If you are building '
      'from source, make sure $_assetDirectory/ is listed under '
      '"flutter: assets:" in pubspec.yaml.',
      file: name,
      cause: error,
    );
  }
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// Writes [bytes] to [target] through a sibling `.part` file and a rename.
///
/// The rename is atomic within a filesystem, so an interrupted write leaves
/// either the previous file or no file - never a half-written one that would
/// pass the next launch's verification.
Future<void> _writeAtomically(
  File target,
  Uint8List bytes, {
  String? expectedSha256,
}) async {
  final name = p.basename(target.path);
  final part = File('${target.path}.part');
  try {
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(target.path);
  } on FileSystemException catch (error) {
    await _deleteQuietly(part);
    throw EphemerisAssetException(
      'Could not install the Swiss Ephemeris file "$name" '
      '(${error.osError?.message ?? error.message}). Free up storage space in '
      'the app\'s documents directory and reopen Tithi.',
      file: name,
      cause: error,
    );
  }

  final problem = await _invalidReason(target, expectedSha256: expectedSha256);
  if (problem != null) {
    throw EphemerisAssetException(
      'The Swiss Ephemeris file "$name" was written to ${target.path} but did '
      'not survive verification ($problem). The device storage may be failing; '
      'free up space and reopen Tithi.',
      file: name,
    );
  }
}

/// Returns why [file] is not a usable ephemeris file, or `null` when it is.
///
/// [expectedSha256] is the manifest entry for this file. When supplied, the
/// whole file is hashed, which catches a copy that kept a valid size and header
/// but lost or gained bytes in the middle.
Future<String?> _invalidReason(File file, {String? expectedSha256}) async {
  final FileStat stat;
  try {
    stat = await file.stat();
  } on FileSystemException {
    return 'it cannot be read';
  }
  if (stat.type == FileSystemEntityType.notFound) return 'it is missing';
  if (stat.type != FileSystemEntityType.file) return 'it is not a file';
  if (stat.size < _minSe1Bytes) return 'it is only ${stat.size} bytes';

  try {
    final handle = await file.open();
    try {
      final header = await handle.read(_se1Magic.length);
      if (header.length < _se1Magic.length) return 'its header is truncated';
      for (var i = 0; i < _se1Magic.length; i++) {
        if (header[i] != _se1Magic[i]) {
          return 'it is not a Swiss Ephemeris data file';
        }
      }
    } finally {
      await handle.close();
    }

    if (expectedSha256 != null) {
      final digest = await file.openRead().transform(sha256).single;
      if (digest.toString() != expectedSha256) {
        return 'its contents do not match the expected checksum';
      }
    }
  } on FileSystemException {
    return 'it cannot be read';
  }
  return null;
}

/// Same checks as [_invalidReason], applied to bytes still in memory.
String? _invalidBytesReason(Uint8List bytes, {String? expectedSha256}) {
  if (bytes.length < _minSe1Bytes) return 'it is only ${bytes.length} bytes';
  for (var i = 0; i < _se1Magic.length; i++) {
    if (bytes[i] != _se1Magic[i]) {
      return 'it does not start with the Swiss Ephemeris header';
    }
  }
  if (expectedSha256 != null &&
      sha256.convert(bytes).toString() != expectedSha256) {
    return 'its checksum does not match the build manifest';
  }
  return null;
}

/// Best-effort removal of a staging file; a leftover `.part` is harmless, so
/// a failure here must not mask the original error.
Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Ignored on purpose.
  }
}
