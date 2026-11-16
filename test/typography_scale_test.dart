// Regression guard for the type scale consolidation.
//
// Before this, sizes were 21 un-named values (9, 10, 10.5, 11, 11.5, 12, 12.5,
// 13, 13.5, 14, 14.5, 15, 16, 17, 18, 19, 20, 22, 24, 32, 64) and weights had
// three spellings for two faces. Text now picks a token from
// `AppTypography.sizeLadder` / `AppTypography.regular..bold`, and the theme
// supplies the family - so a raw number in a widget is drift by definition.
//
// The checks are textual on purpose: they must fail the moment a literal
// reappears, whether or not it compiles.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only file allowed to name a size or a weight.
const String _typeSource = 'lib/theme/app_typography.dart';

void main() {
  group('Typography scale guard', () {
    test('lib/ has no numeric fontSize literals', () {
      final offenders = _matchesInLib(
        (line) => RegExp(r'fontSize:\s*\d').hasMatch(line),
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'Pick a step from AppTypography.sizeLadder (sizeMicro..sizeGlyph) '
            'instead of a raw number - see lib/theme/app_typography.dart.',
      );
    });

    test('lib/ has no raw FontWeight literals', () {
      final offenders = _matchesInLib((line) => line.contains('FontWeight.'));
      expect(
        offenders,
        isEmpty,
        reason:
            'Use AppTypography.regular / medium / semibold / bold. The bundled '
            'families ship 400/500/600/700 only, so FontWeight.w800 rendered as '
            '700 all along.',
      );
    });

    test('every file that styles text imports the type system', () {
      final files = Directory('lib')
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => file.path.replaceAll(r'\', '/') != _typeSource);

      final offenders = <String>[];
      for (final file in files) {
        final source = file.readAsStringSync();
        if (!source.contains('AppTypography.')) continue;
        if (source.contains('theme/app_typography.dart') ||
            source.contains("'app_typography.dart'")) {
          continue;
        }
        offenders.add(file.path);
      }

      expect(
        offenders,
        isEmpty,
        reason: 'A file that names AppTypography must import it.',
      );
    });
  });
}

/// `path:line: text` for every match of [hit] under `lib/`, excluding the one
/// file that defines the tokens.
List<String> _matchesInLib(bool Function(String line) hit) {
  final matches = <String>[];
  for (final entity in Directory(
    'lib',
  ).listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.replaceAll(r'\', '/') == _typeSource) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (hit(lines[i])) {
        matches.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return matches;
}
