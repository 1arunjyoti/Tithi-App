import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/ai/domain/ai_app_target.dart';

/// The hand-off picks a package list here, not in the service, so the choice
/// is testable without Android.
void main() {
  group('aiHandoffCandidates', () {
    test('automatic tries every known app, Gemini first', () {
      final candidates = aiHandoffCandidates(kAiTargetAuto);

      expect(
        candidates.map((target) => target.id),
        kAiAppTargets.map((target) => target.id),
      );
      expect(candidates.first.id, 'gemini');
    });

    test('an explicit choice yields exactly that app', () {
      final candidates = aiHandoffCandidates('chatgpt');

      expect(candidates, hasLength(1));
      expect(candidates.single.label, 'ChatGPT');
      expect(candidates.single.packageName, 'com.openai.chatgpt');
    });

    test('an unknown or removed id degrades to automatic', () {
      // A settings value written by a build that shipped a different list must
      // never block the hand-off.
      expect(aiHandoffCandidates('gone-in-2027'), kAiAppTargets);
    });
  });

  group('kAiAppTargets', () {
    test('ids and package names are unique and never the automatic marker', () {
      final ids = kAiAppTargets.map((target) => target.id).toSet();
      final packages = kAiAppTargets.map((target) => target.packageName).toSet();

      expect(ids, hasLength(kAiAppTargets.length));
      expect(packages, hasLength(kAiAppTargets.length));
      expect(ids, isNot(contains(kAiTargetAuto)));
    });

    test('every declared target resolves back from its id', () {
      for (final target in kAiAppTargets) {
        expect(aiTargetById(target.id), same(target));
      }
    });
  });

  group('aiTargetById', () {
    test('automatic and null map to no target', () {
      expect(aiTargetById(kAiTargetAuto), isNull);
      expect(aiTargetById(null), isNull);
    });

    test('unlisted ids map to no target', () {
      expect(aiTargetById(''), isNull);
      expect(aiTargetById('GEMINI'), isNull);
    });
  });
}
