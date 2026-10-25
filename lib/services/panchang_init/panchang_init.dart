import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show AssetBundle;
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

/// Every Swiss Ephemeris `.se1` file starts with the ASCII header
/// `SWISSEPH  1\r\n`. Only the first word is checked: the digit is a file
/// format version, and a future format bump should not be mistaken for a
/// corrupt file.
final Uint8List _se1Magic = Uint8List.fromList('SWISSEPH'.codeUnits);

/// Smallest plausible `.se1` file. The bundled trio is 223 KB-1.3 MB; anything
/// under a kilobyte is a truncated copy or a stray placeholder, not data Swiss
/// Ephemeris can read.
const int _minSe1Bytes = 1024;

/// Raised when the bundled ephemeris data cannot be installed.
///
/// [message] is written for the user, not the developer: it names the file and
/// the recovery step, because on a device the only available action is to
/// reinstall. Callers surface it verbatim instead of inventing their own copy.
class EphemerisAssetException implements Exception {
  const EphemerisAssetException(this.message, {this.file, this.cause});

  /// User-facing explanation of what failed and what to do about it.
  final String message;

  /// Name of the offending `.se1` file, when one can be identified.
  final String? file;

  /// Underlying error, kept for logs and tests.
  final Object? cause;

  @override
  String toString() =>
      'EphemerisAssetException${file == null ? '' : '($file)'}: $message';
}

/// Copies the bundled ephemeris files to the app's documents directory.
///
/// Returns the directory Swiss Ephemeris should be pointed at.
///
/// A file is copied only when the installed copy is missing or fails
/// verification (size + `SWISSEPH` header). The old "exists, so keep it" check
/// trusted a copy that a killed first launch or a corrupt install could have
/// left truncated, and Swiss Ephemeris then failed later with an opaque
/// `swe_calc` error far from the cause.
Future<String> copyEphemerisFiles(AssetBundle bundle) async {
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
    final target = File(p.join(epheDir.path, name));
    if (await _invalidReason(target) == null) continue;

    final bytes = await _readAsset(bundle, name);
    final assetProblem = _invalidBytesReason(bytes);
    if (assetProblem != null) {
      throw EphemerisAssetException(
        'The Swiss Ephemeris file "$name" bundled with the app is not usable '
        '($assetProblem). Reinstall the app to restore it. If you are building '
        'from source, put a valid $name in $_assetDirectory/ and rebuild.',
        file: name,
      );
    }

    await _writeAtomically(target, bytes);
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
/// pass the next launch's size check.
Future<void> _writeAtomically(File target, Uint8List bytes) async {
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

  final problem = await _invalidReason(target);
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
Future<String?> _invalidReason(File file) async {
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
  } on FileSystemException {
    return 'it cannot be read';
  }
  return null;
}

/// Same checks as [_invalidReason], applied to bytes still in memory.
String? _invalidBytesReason(Uint8List bytes) {
  if (bytes.length < _minSe1Bytes) return 'it is only ${bytes.length} bytes';
  for (var i = 0; i < _se1Magic.length; i++) {
    if (bytes[i] != _se1Magic[i]) {
      return 'it does not start with the Swiss Ephemeris header';
    }
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
