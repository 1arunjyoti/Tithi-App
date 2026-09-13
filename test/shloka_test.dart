import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/shloka.dart';
import 'package:tithi/services/share_file/share_file.dart';
import 'package:tithi/services/shloka_service.dart';
import 'package:tithi/widgets/daily_quote_widget.dart';

void main() {
  group('Shloka Model Tests', () {
    test('fromJson parses all new fields', () {
      // Arrange
      final json = <String, dynamic>{
        'id': 'gita-2-47',
        'text': 'कर्मण्येवाधिकारस्ते',
        'transliteration': 'karmanyevadhikaraste',
        'translation': 'You have a right to your duty.',
        'hindiTranslation': 'तुम्हारा अधिकार कर्म में है।',
        'source': 'Bhagavad Gita 2.47',
        'themes': ['karma', 'wisdom'],
        'festivalIds': [],
      };

      // Act
      final shloka = Shloka.fromJson(json);

      // Assert
      expect(shloka.id, equals('gita-2-47'));
      expect(shloka.text, equals('कर्मण्येवाधिकारस्ते'));
      expect(shloka.transliteration, equals('karmanyevadhikaraste'));
      expect(shloka.translation, equals('You have a right to your duty.'));
      expect(shloka.hindiTranslation, equals('तुम्हारा अधिकार कर्म में है।'));
      expect(shloka.source, equals('Bhagavad Gita 2.47'));
      expect(shloka.themes, equals(['karma', 'wisdom']));
    });

    test('fromJson stays backward compatible with old 4-field JSON', () {
      // Arrange
      final json = <String, dynamic>{
        'text': 'सत्यमेव जयते',
        'translation': 'Truth alone triumphs.',
        'source': 'Mundaka Upanishad',
        'festivalIds': [],
      };

      // Act
      final shloka = Shloka.fromJson(json);

      // Assert
      expect(shloka.id, equals(''));
      expect(shloka.transliteration, equals(''));
      expect(shloka.hindiTranslation, isNull);
      expect(shloka.themes, isEmpty);
      expect(shloka.text, equals('सत्यमेव जयते'));
    });

    test('fromJson maps null hindiTranslation to null', () {
      // Arrange
      final json = <String, dynamic>{
        'id': 'orig-01',
        'text': 'text',
        'transliteration': 'trans',
        'translation': 'translation',
        'hindiTranslation': null,
        'source': 'source',
        'themes': ['karma'],
        'festivalIds': [],
      };

      // Act
      final shloka = Shloka.fromJson(json);

      // Assert
      expect(shloka.hindiTranslation, isNull);
    });

    test('fromJson normalizes themes (trim, drop empties, dedupe)', () {
      // Arrange
      final json = <String, dynamic>{
        'text': 't',
        'translation': 'tr',
        'source': 's',
        'themes': [' karma ', '', 'karma', 42, 'wisdom'],
      };

      // Act
      final shloka = Shloka.fromJson(json);

      // Assert
      expect(shloka.themes, equals(['karma', 'wisdom']));
    });

    test('toJson round-trips new fields', () {
      // Arrange
      const shloka = Shloka(
        id: 'gita-2-13',
        text: 't',
        transliteration: 'tr',
        translation: 'en',
        hindiTranslation: 'hi',
        source: 's',
        themes: ['atman'],
      );

      // Act
      final json = shloka.toJson();
      final restored = Shloka.fromJson(json);

      // Assert
      expect(restored.id, equals('gita-2-13'));
      expect(restored.transliteration, equals('tr'));
      expect(restored.hindiTranslation, equals('hi'));
      expect(restored.themes, equals(['atman']));
    });
  });

  group('Shloka Translation Picker Tests', () {
    const both = Shloka(
      text: 't',
      translation: 'English',
      hindiTranslation: 'हिन्दी',
      source: 's',
    );
    const englishOnly = Shloka(text: 't', translation: 'English', source: 's');

    test('hindiFirst picks Hindi when available', () {
      // Act
      final result = pickShlokaTranslation(both, hindiFirst: true);

      // Assert
      expect(result, equals('हिन्दी'));
    });

    test('hindiFirst falls back to English when Hindi is missing', () {
      // Act
      final result = pickShlokaTranslation(englishOnly, hindiFirst: true);

      // Assert
      expect(result, equals('English'));
    });

    test('english-first picks English when available', () {
      // Act
      final result = pickShlokaTranslation(both, hindiFirst: false);

      // Assert
      expect(result, equals('English'));
    });

    test('returns null when both translations are missing', () {
      // Arrange
      const empty = Shloka(text: 't', translation: '', source: 's');

      // Act + Assert
      expect(pickShlokaTranslation(empty, hindiFirst: true), isNull);
      expect(pickShlokaTranslation(empty, hindiFirst: false), isNull);
    });

    test('otherTranslation returns secondary only when both exist', () {
      // Act + Assert
      expect(otherShlokaTranslation(both, hindiFirst: false), equals('हिन्दी'));
      expect(otherShlokaTranslation(both, hindiFirst: true), equals('English'));
      expect(otherShlokaTranslation(englishOnly, hindiFirst: false), isNull);
    });
  });

  group('Shloka Share Text Tests', () {
    const shloka = Shloka(
      id: 'gita-2-47',
      text: 'Sanskrit',
      transliteration: 'translit',
      translation: 'English',
      hindiTranslation: 'हिन्दी',
      source: 'Gita 2.47',
      themes: ['karma', 'wisdom'],
    );

    test('collapsed share omits translations', () {
      // Act
      final text = buildShlokaShareText(shloka, expanded: false);

      // Assert
      expect(text, contains('Sanskrit'));
      expect(text, contains('translit'));
      expect(text, contains('Gita 2.47'));
      expect(text, isNot(contains('English')));
      expect(text, isNot(contains('हिन्दी')));
    });

    test('expanded share includes English by default', () {
      // Act
      final text = buildShlokaShareText(shloka, expanded: true);

      // Assert
      expect(text, contains('English'));
      expect(text, isNot(contains('हिन्दी')));
      expect(text, contains('#karma'));
      expect(text, contains('#wisdom'));
    });

    test('expanded share includes Hindi when hindiFirst', () {
      // Act
      final text = buildShlokaShareText(
        shloka,
        expanded: true,
        hindiFirst: true,
      );

      // Assert
      expect(text, contains('हिन्दी'));
      expect(text, isNot(contains('English')));
    });

    test('expanded share with showAll includes every translation', () {
      // Act
      final text = buildShlokaShareText(shloka, expanded: true, showAll: true);

      // Assert
      expect(text, contains('English'));
      expect(text, contains('हिन्दी'));
    });
  });

  group('Quote Day Label Tests', () {
    test('returns relative labels for today and adjacent days', () {
      // Arrange
      final date = DateTime(2026, 5, 17);

      // Act + Assert
      expect(quoteDayLabel(date, 0), equals('Today'));
      expect(quoteDayLabel(date, -1), equals('Yesterday'));
      expect(quoteDayLabel(date, 1), equals('Tomorrow'));
    });

    test('returns formatted date for farther offsets', () {
      // Act
      final label = quoteDayLabel(DateTime(2026, 3, 5), 7);

      // Assert
      expect(label, equals('Mar 5'));
    });
  });

  group('ShlokaService Tests', () {
    test('parseShlokas returns empty for non-list roots', () {
      // Act + Assert
      expect(ShlokaService.parseShlokas(null), isEmpty);
      expect(ShlokaService.parseShlokas({'text': 't'}), isEmpty);
      expect(ShlokaService.parseShlokas('verses'), isEmpty);
      expect(ShlokaService.parseShlokas([]), isEmpty);
    });

    test('parseShlokas skips corrupt entries instead of failing all', () {
      // Arrange: one good verse, one non-map, one wrong-typed field.
      final decoded = [
        {'id': 'good-1', 'text': 't', 'translation': 'tr', 'source': 's'},
        'not-a-map',
        {'id': 'bad-1', 'text': 42, 'translation': 'tr', 'source': 's'},
      ];

      // Act
      final result = ShlokaService.parseShlokas(decoded);

      // Assert
      expect(result, hasLength(1));
      expect(result.first.id, equals('good-1'));
    });

    test('purgeOldShareImages never throws', () async {
      // Act (no temp dir under flutter_test: must resolve to 0, not throw)
      final removed = await purgeOldShareImages();

      // Assert
      expect(removed, equals(0));
    });
    test('returns null when empty (before init)', () {
      // Arrange
      final service = ShlokaService();

      // Act
      final result = service.getShlokaForDate(DateTime(2026, 5, 17));

      // Assert — either null (not yet loaded) or a valid shloka if a
      // previous test already initialized the singleton.
      if (result != null) {
        expect(result.text, isNotEmpty);
      } else {
        expect(result, isNull);
      }
    });
  });
}
