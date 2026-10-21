// Regression guard for the web-target removal (docs/web-removal/BASELINE.md).
//
// The `web/` target, every `kIsWeb` branch and every web conditional import
// were deleted on purpose. A future web app is a separate project, so nothing
// in this one should grow web scaffolding back.
//
// The checks are deliberately textual: they must fail the moment the code
// reappears, whether or not it compiles.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web removal regression guard', () {
    test('the web/ platform directory stays deleted', () {
      expect(
        Directory('web').existsSync(),
        isFalse,
        reason:
            'web/ is a deleted platform target. Do not restore it - a real web '
            'app is a separate project (docs/web-removal/BASELINE.md).',
      );
    });

    test('lib/ has no kIsWeb branching', () {
      final offenders = _matchesInDartFiles('lib', (line) => line.contains('kIsWeb'));
      expect(
        offenders,
        isEmpty,
        reason:
            'kIsWeb guards went away with the web target. Gate platform '
            'behaviour with Platform.isAndroid / defaultTargetPlatform instead '
            '(AGENTS.md, "Platform-Specific Code").',
      );
    });

    test('lib/ has no conditional imports or exports', () {
      // `if (dart.library.*)` only existed to swap a stub in per platform;
      // runtime checks replaced it (AGENTS.md, "Platform-Specific Code").
      final offenders = _matchesInDartFiles(
        'lib',
        (line) => line.contains('dart.library.'),
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'Conditional exports were removed: there is no second platform to '
            'stub out. Use a runtime Platform guard instead.',
      );
    });

    test('platform config does not target web', () {
      expect(
        _lines('analysis_options.yaml').where((line) => line.contains('web/**')),
        isEmpty,
        reason: 'analysis_options.yaml no longer needs a web/** exclusion.',
      );

      expect(
        _lines('flutter_launcher_icons.yaml')
            .where((line) => line.trimLeft().startsWith('web:')),
        isEmpty,
        reason: 'flutter_launcher_icons.yaml no longer generates web icons.',
      );

      expect(
        _lines('.metadata').where((line) => line.contains('platform: web')),
        isEmpty,
        reason: '.metadata should not list a web platform.',
      );
    });
  });
}

/// `path:line: text` for every match of [hit] across the `.dart` files under
/// [root]. Relative paths, because tests run from the package root.
List<String> _matchesInDartFiles(String root, bool Function(String line) hit) {
  final directory = Directory(root);
  if (!directory.existsSync()) return const <String>[];

  final matches = <String>[];
  for (final entity in directory.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (hit(lines[i])) matches.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
    }
  }
  return matches;
}

/// Lines of a repo-root config file, or none if it is absent.
List<String> _lines(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsLinesSync() : const <String>[];
}
