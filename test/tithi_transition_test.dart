// Tests for the two-tithi (daytime transition) display logic.
//
// Covers the "three tithis, two days" squeeze: a short tithi (e.g. Navami
// on Oct 4 2026) can begin after one sunrise and end before the next, so it
// never prevails at any sunrise. The provider locates the first boundary
// after sunrise so the day shows both tithis ("Ashtami → Navami").
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/panchang_provider.dart';

/// Fake raw-tithi source switching from [fromRaw] to [toRaw] at [boundary].
Future<double> Function(DateTime) fakeTithiSource({
  required double fromRaw,
  required double toRaw,
  required DateTime boundary,
}) {
  return (DateTime t) async => t.isBefore(boundary) ? fromRaw : toRaw;
}

void main() {
  group('findSunriseTithiTransition', () {
    test('finds mid-day boundary to ~1 minute', () async {
      // Arrange
      final sunrise = DateTime(2026, 10, 3, 5, 28);
      final nextSunrise = DateTime(2026, 10, 4, 5, 28);
      final boundary = DateTime(2026, 10, 3, 8, 10);
      final getRawTithi = fakeTithiSource(
        fromRaw: 21.5,
        toRaw: 22.5,
        boundary: boundary,
      );

      // Act
      final found = await findSunriseTithiTransition(
        sunrise: sunrise,
        nextSunrise: nextSunrise,
        rawTithiAtSunrise: 21.5,
        segments: [
          (time: sunrise, rawTithi: 21.5),
          (time: DateTime(2026, 10, 3, 12), rawTithi: 22.5),
          (time: DateTime(2026, 10, 3, 18), rawTithi: 22.5),
          (time: DateTime(2026, 10, 4), rawTithi: 22.5),
          (time: nextSunrise, rawTithi: 22.5),
        ],
        getRawTithi: getRawTithi,
      );

      // Assert
      expect(found, isNotNull);
      expect(found!.toIndex, equals(22));
      expect(
        found.at.difference(boundary).inMinutes.abs(),
        lessThanOrEqualTo(2),
      );
    });

    test('squeeze case surfaces the first boundary (Ashtami → Navami)', () async {
      // Arrange: Oct 4 2026 — Ashtami ends 05:53, Navami ends before the
      // next sunrise, so consecutive sunrises read Ashtami then Dashami.
      final sunrise = DateTime(2026, 10, 4, 5, 28);
      final nextSunrise = DateTime(2026, 10, 5, 5, 29);
      final ashtamiEnd = DateTime(2026, 10, 4, 5, 53);
      Future<double> getRawTithi(DateTime t) async {
        if (t.isBefore(ashtamiEnd)) return 23.98;
        if (t.isBefore(DateTime(2026, 10, 5, 4, 20))) return 24.5;
        return 25.07;
      }

      // Act
      final found = await findSunriseTithiTransition(
        sunrise: sunrise,
        nextSunrise: nextSunrise,
        rawTithiAtSunrise: 23.98,
        segments: [
          (time: sunrise, rawTithi: 23.98),
          (time: DateTime(2026, 10, 4, 12), rawTithi: 24.5),
          (time: DateTime(2026, 10, 4, 18), rawTithi: 24.5),
          (time: DateTime(2026, 10, 5), rawTithi: 24.5),
          (time: nextSunrise, rawTithi: 25.07),
        ],
        getRawTithi: getRawTithi,
      );

      // Assert: Navami (index 24) is surfaced even though no sunrise reads it.
      expect(found, isNotNull);
      expect(found!.toIndex, equals(24));
      expect(
        found.at.difference(ashtamiEnd).inMinutes.abs(),
        lessThanOrEqualTo(2),
      );
    });

    test('returns null when sunrise tithi prevails at next sunrise', () async {
      // Arrange
      final sunrise = DateTime(2026, 10, 6, 5, 29);
      final nextSunrise = DateTime(2026, 10, 7, 5, 30);

      // Act
      final found = await findSunriseTithiTransition(
        sunrise: sunrise,
        nextSunrise: nextSunrise,
        rawTithiAtSunrise: 25.5,
        segments: [
          (time: sunrise, rawTithi: 25.5),
          (time: DateTime(2026, 10, 6, 12), rawTithi: 25.6),
          (time: DateTime(2026, 10, 6, 18), rawTithi: 25.7),
          (time: DateTime(2026, 10, 7), rawTithi: 25.8),
          (time: nextSunrise, rawTithi: 25.9),
        ],
        getRawTithi: (t) async => 25.5,
      );

      // Assert
      expect(found, isNull);
    });

    test('wraps Amavasya (30) to Pratipada (1)', () async {
      // Arrange
      final sunrise = DateTime(2026, 10, 10, 5, 30);
      final nextSunrise = DateTime(2026, 10, 11, 5, 30);
      final boundary = DateTime(2026, 10, 10, 14);

      // Act
      final found = await findSunriseTithiTransition(
        sunrise: sunrise,
        nextSunrise: nextSunrise,
        rawTithiAtSunrise: 30.5,
        segments: [
          (time: sunrise, rawTithi: 30.5),
          (time: DateTime(2026, 10, 10, 18), rawTithi: 1.5),
          (time: nextSunrise, rawTithi: 1.6),
        ],
        getRawTithi: fakeTithiSource(
          fromRaw: 30.5,
          toRaw: 1.5,
          boundary: boundary,
        ),
      );

      // Assert
      expect(found, isNotNull);
      expect(found!.toIndex, equals(1));
      expect(
        found.at.difference(boundary).inMinutes.abs(),
        lessThanOrEqualTo(2),
      );
    });

    test('returns null when validation finds the wrong tithi past it', () async {
      // Arrange: checkpoints claim a transition, but the source never leaves
      // the sunrise tithi (stale/noisy checkpoint data).
      final sunrise = DateTime(2026, 10, 4, 5, 28);
      final nextSunrise = DateTime(2026, 10, 5, 5, 29);

      // Act
      final found = await findSunriseTithiTransition(
        sunrise: sunrise,
        nextSunrise: nextSunrise,
        rawTithiAtSunrise: 23.5,
        segments: [
          (time: sunrise, rawTithi: 23.5),
          (time: DateTime(2026, 10, 4, 12), rawTithi: 24.5),
          (time: nextSunrise, rawTithi: 24.5),
        ],
        getRawTithi: (t) async => 23.5,
      );

      // Assert
      expect(found, isNull);
    });
  });

  group('PanchangData transition getters', () {
    test('squeeze day exposes Navami as the incoming tithi', () {
      // Arrange + Act
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 10, 4),
        rawTithi: 23.98,
        tithiTransitionTime: DateTime(2026, 10, 4, 5, 53),
        transitionTithiIndex: 24,
      );

      // Assert
      expect(panchang.paksha, equals('Krishna'));
      expect(panchang.tithiName, equals('Ashtami'));
      expect(panchang.hasTithiTransition, isTrue);
      expect(panchang.transitionPaksha, equals('Krishna'));
      expect(panchang.transitionTithiNumber, equals(9));
      expect(panchang.transitionTithiName, equals('Navami'));
    });

    test('day without transition reports none', () {
      // Arrange + Act
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 10, 6),
        rawTithi: 25.5,
      );

      // Assert
      expect(panchang.hasTithiTransition, isFalse);
    });

    test('transition equal to sunrise tithi is ignored', () {
      // Arrange + Act
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 10, 4),
        rawTithi: 23.98,
        tithiTransitionTime: DateTime(2026, 10, 4, 5, 53),
        transitionTithiIndex: 23,
      );

      // Assert
      expect(panchang.hasTithiTransition, isFalse);
    });

    test('wrap transition resolves to Shukla Pratipada', () {
      // Arrange + Act
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 10, 10),
        rawTithi: 30.5,
        tithiTransitionTime: DateTime(2026, 10, 10, 14),
        transitionTithiIndex: 1,
      );

      // Assert
      expect(panchang.tithiName, equals('Amavasya'));
      expect(panchang.hasTithiTransition, isTrue);
      expect(panchang.transitionPaksha, equals('Shukla'));
      expect(panchang.transitionTithiName, equals('Pratipada'));
    });
  });
}
