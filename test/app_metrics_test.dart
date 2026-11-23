// Regression guard for the layout scale (spacing, radius, icon sizes).
//
// Before this, `lib/` carried ~60 one-off EdgeInsets numbers, 18 distinct
// corner radii and 13 ad-hoc icon sizes, with the same gap written as 10 in
// one sheet and 12 in the next. Padding and gaps up to 32dp now come from
// `AppSpacing`, corners from `AppRadius` and icon sizes from `AppIconSize`.
//
// The checks are textual on purpose: they must fail the moment a literal
// reappears, whether or not it compiles.

import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/theme/app_metrics.dart';

/// The files allowed to name a raw value: the scale itself, and the theme
/// that owns the sheet/dialog shapes.
const Set<String> _exempt = <String>{'lib/theme/app_metrics.dart'};

void main() {
  group('AppSpacing', () {
    test('is ascending, unique and on the 2dp grid', () {
      const ladder = AppSpacing.ladder;
      expect(ladder, isNotEmpty);
      expect(ladder.first, AppSpacing.s2);
      expect(ladder.last, AppSpacing.maxStep);

      for (var i = 1; i < ladder.length; i++) {
        expect(
          ladder[i],
          greaterThan(ladder[i - 1]),
          reason: 'the spacing ladder must stay ascending',
        );
      }
      expect(ladder.toSet().length, ladder.length);

      for (final step in ladder) {
        expect(
          step % 2,
          equals(0),
          reason:
              '$step is off the 2dp grid - half steps are the drift this '
              'scale exists to stop',
        );
        expect(step, lessThanOrEqualTo(AppSpacing.maxStep));
      }
    });

    test('maxStep is the largest named step', () {
      expect(
        AppSpacing.maxStep,
        AppSpacing.s32,
        reason: 'anything above this is a component dimension, not a gap',
      );
    });
  });

  group('AppRadius', () {
    test('is a short ascending scale ending in the pill', () {
      const ladder = AppRadius.ladder;
      expect(ladder.length, lessThanOrEqualTo(10));
      for (var i = 1; i < ladder.length; i++) {
        expect(ladder[i], greaterThan(ladder[i - 1]));
      }
      expect(ladder.first, AppRadius.micro);
      expect(ladder.last, AppRadius.pill);
    });

    test('the retired one-off radii are gone', () {
      // 1/3 folded into micro, 6 into chip, 10/13 into dense, 14 into tile,
      // 28 into card, 50/99 into pill.
      for (final retired in <double>[1, 3, 6, 10, 13, 14, 28, 50, 99]) {
        expect(
          AppRadius.ladder,
          isNot(contains(retired)),
          reason: '$retired was snapped to a role',
        );
      }
    });

    test('sheetTop uses the sheet step', () {
      expect(
        AppRadius.sheetTop.topLeft,
        const Radius.circular(AppRadius.sheet),
      );
      expect(
        AppRadius.sheetTop.topRight,
        const Radius.circular(AppRadius.sheet),
      );
      expect(AppRadius.sheetTop.bottomLeft, Radius.zero);
    });
  });

  group('AppIconSize', () {
    test('is ascending, unique and covers the shipped sizes', () {
      const ladder = AppIconSize.ladder;
      for (var i = 1; i < ladder.length; i++) {
        expect(ladder[i], greaterThan(ladder[i - 1]));
      }
      expect(ladder.toSet().length, ladder.length);

      // Sizes actually shipped in the UI; an icon step cannot be dropped
      // without repainting something.
      for (final size in <double>[14, 16, 18, 20, 22, 24, 28, 32, 48, 64]) {
        expect(ladder, contains(size));
      }
    });
  });

  group('Layout scale guard', () {
    test('lib/ has no numeric EdgeInsets padding', () {
      final offenders = <String>[];
      for (final file in _dartFiles()) {
        final source = file.readAsStringSync();
        for (final ctor in <String>[
          'EdgeInsets.all(',
          'EdgeInsets.symmetric(',
          'EdgeInsets.only(',
          'EdgeInsets.fromLTRB(',
        ]) {
          for (final span in _spans(source, ctor)) {
            for (final arg in _topLevelArgs(span)) {
              final value = _numericValue(arg);
              if (value != null && value > 0 && value <= AppSpacing.maxStep) {
                offenders.add('${_relative(file)}: $arg');
              }
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use AppSpacing.s2..s32 for padding and gaps up to '
            '${AppSpacing.maxStep.toInt()}dp. Above that the number is a '
            'component dimension and stays where the widget owns it.',
      );
    });

    test('lib/ has no numeric SizedBox gap', () {
      final offenders = <String>[];
      for (final file in _dartFiles()) {
        final source = file.readAsStringSync();
        for (final span in _spans(source, 'SizedBox(')) {
          final args = _topLevelArgs(span);
          // A SizedBox with a child is a fixed-size box (a spinner, a
          // thumbnail), not a gap: the number is the component's dimension
          // and belongs at the widget that owns it.
          if (args.any((arg) => arg.trimLeft().startsWith('child:'))) {
            continue;
          }
          for (final arg in args) {
            final value = _numericValue(arg);
            if (value != null && AppSpacing.ladder.contains(value)) {
              offenders.add('${_relative(file)}: $arg');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'A gap on the ladder must use AppSpacing. 1dp rules and sizes '
            'above ${AppSpacing.maxStep.toInt()}dp are dimensions, not gaps.',
      );
    });

    test('lib/ has no numeric corner radius', () {
      final offenders = <String>[];
      final pattern = RegExp(
        r'(?:BorderRadius|Radius)\.circular\(\s*\d+(?:\.\d+)?\s*\)'
        r'|borderRadius:\s*\d+(?:\.\d+)?',
      );
      for (final file in _dartFiles()) {
        final source = file.readAsStringSync();
        for (final match in pattern.allMatches(source)) {
          offenders.add('${_relative(file)}: ${match.group(0)}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use AppRadius.micro..pill. A raw corner is how the app ended up '
            'with 18 radii for 9 surfaces.',
      );
    });

    test('lib/ has no numeric Icon size', () {
      final offenders = <String>[];
      final params = RegExp(r'(?:iconSize|glyphSize):\s*\d+(?:\.\d+)?');
      for (final file in _dartFiles()) {
        final source = file.readAsStringSync();
        for (final span in _spans(source, 'Icon(')) {
          if (RegExp(r'size:\s*\d').hasMatch(span)) {
            offenders.add('${_relative(file)}: $span');
          }
        }
        for (final match in params.allMatches(source)) {
          offenders.add('${_relative(file)}: ${match.group(0)}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use AppIconSize.inline..splash. 14/16/18/20/22/24/28/32/48/64 '
            'are all shipped sizes; they have names now.',
      );
    });
  });
}

/// Every `.dart` file under `lib/` except the scale itself.
Iterable<File> _dartFiles() {
  return Directory('lib')
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !_exempt.contains(_relative(file)));
}

String _relative(File file) => file.path.replaceAll(r'\', '/');

/// Balanced-paren spans that start with [prefix], e.g. `Icon( ... )`.
///
/// A naive line regex cannot see a multi-line constructor, and `Icon(` also
/// appears inside `IconButton(icon: Icon(...))`; counting parens handles both.
List<String> _spans(String source, String prefix) {
  final spans = <String>[];
  var searchFrom = 0;
  while (true) {
    final start = source.indexOf(prefix, searchFrom);
    if (start < 0) break;

    // Skip a match that is part of a longer identifier (e.g. an `Icon(` in
    // `AppIcon(` or a doc-comment mention).
    final before = start == 0 ? '' : source[start - 1];
    if (RegExp(r'[A-Za-z0-9_]').hasMatch(before)) {
      searchFrom = start + prefix.length;
      continue;
    }

    final open = start + prefix.length - 1;
    if (source[open] != '(') {
      searchFrom = start + prefix.length;
      continue;
    }

    var depth = 0;
    var end = -1;
    for (var i = open; i < source.length; i++) {
      final char = source[i];
      if (char == '(') depth++;
      if (char == ')') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    if (end < 0) break;

    spans.add(source.substring(start, end + 1));
    searchFrom = end + 1;
  }
  return spans;
}

/// Top-level comma-separated arguments of a span, with the constructor's
/// parens stripped.
List<String> _topLevelArgs(String span) {
  final open = span.indexOf('(');
  final inner = span.substring(open + 1, span.length - 1);
  final args = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (final char in inner.split('')) {
    if (char == '(' || char == '[' || char == '{') depth++;
    if (char == ')' || char == ']' || char == '}') depth--;
    if (char == ',' && depth == 0) {
      args.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  if (buffer.isNotEmpty) args.add(buffer.toString());
  return args;
}

/// The number in an argument that is *only* a value (`height: 12`,
/// `horizontal: 8`, or a positional `16`), ignoring expressions.
double? _numericValue(String arg) {
  final match = RegExp(
    r'^\s*(?:[A-Za-z]+:\s*)?(\d+(?:\.\d+)?)\s*$',
  ).firstMatch(arg);
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}
