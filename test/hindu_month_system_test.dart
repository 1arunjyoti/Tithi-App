import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/hindu_month_system.dart';

/// Amanta → Purnimant month names for Krishna Paksha days, per the
/// Amanta/Purnimant spec: Shukla is identical in both systems, Krishna
/// takes the next month in the Amanta sequence.
const _krishnaMapping = {
  'Chaitra': 'Vaishakha',
  'Vaishakha': 'Jyeshtha',
  'Jyeshtha': 'Ashadha',
  'Ashadha': 'Shravana',
  'Shravana': 'Bhadrapada',
  'Bhadrapada': 'Ashwin',
  'Ashwin': 'Kartika',
  'Kartika': 'Margashirsha',
  'Margashirsha': 'Pausha',
  'Pausha': 'Magha',
  'Magha': 'Phalguna',
  'Phalguna': 'Chaitra',
};

void main() {
  group('Amanta/Purnimant month system', () {
    test('Krishna Paksha follows the spec mapping table', () {
      expect(_krishnaMapping, hasLength(12));
      _krishnaMapping.forEach((amanta, purnimant) {
        expect(
          convertAmantaToPurnimant(amanta, 'Krishna'),
          equals(purnimant),
          reason: 'Krishna $amanta (Amanta) should be $purnimant (Purnimant)',
        );
      });
    });

    test('Reverse mapping restores the Amanta month', () {
      _krishnaMapping.forEach((amanta, purnimant) {
        expect(
          convertPurnimantToAmanta(purnimant, 'Krishna'),
          equals(amanta),
          reason: 'Krishna $purnimant (Purnimant) should be $amanta (Amanta)',
        );
      });
    });

    test('Krishna conversion round-trips for every month', () {
      for (final masa in hinduMonthsOrder) {
        expect(
          convertPurnimantToAmanta(
            convertAmantaToPurnimant(masa, 'Krishna'),
            'Krishna',
          ),
          equals(masa),
        );
      }
    });

    test('Shukla Paksha month names are identical in both systems', () {
      for (final masa in hinduMonthsOrder) {
        expect(convertAmantaToPurnimant(masa, 'Shukla'), equals(masa));
        expect(convertPurnimantToAmanta(masa, 'Shukla'), equals(masa));
      }
    });

    test('Spec examples: Janmashtami and Kamika Ekadashi', () {
      // Janmashtami: Shravana Krishna (Amanta) = Bhadrapada Krishna (Purnimant)
      expect(
        convertAmantaToPurnimant('Shravana', 'Krishna'),
        equals('Bhadrapada'),
      );
      // Kamika Ekadashi: Ashadha Krishna (Amanta) = Shravana Krishna (Purnimant)
      expect(
        convertAmantaToPurnimant('Ashadha', 'Krishna'),
        equals('Shravana'),
      );
    });

    test('Unknown and Adhika masas pass through unchanged', () {
      expect(convertAmantaToPurnimant('', 'Krishna'), equals(''));
      expect(
        convertAmantaToPurnimant('Adhika_Shravana', 'Krishna'),
        equals('Adhika_Shravana'),
      );
      expect(
        convertPurnimantToAmanta('Adhika_Shravana', 'Krishna'),
        equals('Adhika_Shravana'),
      );
    });
  });
}
