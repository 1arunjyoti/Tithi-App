import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_profile.dart';

void main() {
  group('PanchangProfile defaults', () {
    test('standard profile matches the target Panchang contract', () {
      const profile = PanchangProfile.standard;

      expect(profile.ayanamsa, SiderealMode.lahiri);
      expect(profile.monthSystem, HinduMonthSystem.amanta);
      expect(profile.solarConvention, SolarEventConvention.hindu);
      expect(profile.lunarLimb, LunarLimb.upperLimb);
      expect(profile.lunarRefraction, LunarRefraction.standard);
      expect(profile.timezoneId, isNull);
      expect(profile.nodeConvention, NodeConvention.meanNode);
      expect(profile.regionalRuleSetId, isNull);
      expect(profile.calculationVersion, kPanchangCalculationVersion);
    });

    test('standard observance policy enables every documented checkpoint', () {
      const observance = FestivalObservancePolicy.standard;

      expect(observance.checkpoints, ObservanceCheckpoint.values.toSet());
      expect(observance.kshaya, KshayaPolicy.fallback);
      expect(observance.vriddhi, VriddhiPolicy.both);
      expect(observance.dominantTithi, DominantTithiPolicy.grace);
      expect(observance.nishita, NishitaPolicy.windowEdges);
      expect(observance.moonrise, MoonrisePolicy.fallbackToSunrise);
    });

    test('standard enum identifiers match shipped festival data spelling', () {
      expect(
        ObservanceCheckpoint.values.map((checkpoint) => checkpoint.name),
        containsAll(<String>[
          'sunrise',
          'madhyahna',
          'aparahna',
          'nishita',
          'pradosha',
          'moonrise',
        ]),
      );
    });
  });

  group('PanchangProfile serialization', () {
    const custom = PanchangProfile(
      ayanamsa: SiderealMode.raman,
      monthSystem: HinduMonthSystem.purnimant,
      solarConvention: SolarEventConvention.apparentUpperLimb,
      lunarLimb: LunarLimb.center,
      lunarRefraction: LunarRefraction.none,
      timezoneId: 'Asia/Kolkata',
      observance: FestivalObservancePolicy(
        checkpoints: {
          ObservanceCheckpoint.sunrise,
          ObservanceCheckpoint.pradosha,
          ObservanceCheckpoint.moonrise,
        },
        kshaya: KshayaPolicy.strict,
        vriddhi: VriddhiPolicy.first,
        dominantTithi: DominantTithiPolicy.strict,
        nishita: NishitaPolicy.midpoint,
        moonrise: MoonrisePolicy.requireRise,
      ),
      nodeConvention: NodeConvention.trueNode,
      regionalRuleSetId: 'bengali',
      calculationVersion: 7,
    );

    test('round-trips every field', () {
      final decoded = PanchangProfile.fromJson(custom.toJson());

      expect(decoded, custom);
      expect(decoded.hashCode, custom.hashCode);
      expect(decoded.ayanamsa, SiderealMode.raman);
      expect(decoded.monthSystem, HinduMonthSystem.purnimant);
      expect(decoded.solarConvention, SolarEventConvention.apparentUpperLimb);
      expect(decoded.lunarLimb, LunarLimb.center);
      expect(decoded.lunarRefraction, LunarRefraction.none);
      expect(decoded.timezoneId, 'Asia/Kolkata');
      expect(decoded.nodeConvention, NodeConvention.trueNode);
      expect(decoded.regionalRuleSetId, 'bengali');
      expect(decoded.calculationVersion, 7);
      expect(decoded.observance, custom.observance);
      expect(decoded.observance.nishita, NishitaPolicy.midpoint);
      expect(decoded.observance.moonrise, MoonrisePolicy.requireRise);
    });

    test('stores ayanamsa by stable sidereal-mode constant', () {
      final json = custom.toJson();

      expect(json['ayanamsa'], SiderealMode.raman.constant);

      // Decoding keys on the sidereal-mode constant, not the enum position:
      // a value that is not a valid constant must not select an enum by index.
      final unknown = PanchangProfile.fromJson(<String, dynamic>{
        ...json,
        'ayanamsa': 9999,
      });
      expect(unknown.ayanamsa, SiderealMode.lahiri);

      final trueCitra = PanchangProfile.fromJson(<String, dynamic>{
        ...json,
        'ayanamsa': SiderealMode.trueCitra.constant,
      });
      expect(trueCitra.ayanamsa, SiderealMode.trueCitra);
    });

    test('writes a deterministic, sorted checkpoint list', () {
      final json = custom.toJson();
      final observance = json['observance'] as Map<String, dynamic>;

      expect(observance['checkpoints'], <String>[
        'moonrise',
        'pradosha',
        'sunrise',
      ]);
    });

    test('missing or null input falls back to standard', () {
      expect(PanchangProfile.fromJson(null), PanchangProfile.standard);
      expect(
        PanchangProfile.fromJson(<String, dynamic>{}),
        PanchangProfile.standard,
      );
    });

    test('unknown values fall back per field instead of throwing', () {
      final decoded = PanchangProfile.fromJson(<String, dynamic>{
        'ayanamsa': 9999,
        'monthSystem': 'not-a-system',
        'solarConvention': 'nope',
        'lunarLimb': 'nope',
        'lunarRefraction': 'nope',
        'nodeConvention': 'nope',
        'observance': <String, dynamic>{
          'checkpoints': <String>['not-a-checkpoint'],
          'kshaya': 'nope',
          'vriddhi': 'nope',
          'dominantTithi': 'nope',
          'nishita': 'nope',
          'moonrise': 'nope',
        },
      });

      expect(decoded, PanchangProfile.standard);
    });

    test('rejects a profile written by a newer schema', () {
      final decoded = PanchangProfile.fromJson(<String, dynamic>{
        'schema': PanchangProfile.schemaVersion + 1,
        'monthSystem': HinduMonthSystem.purnimant.name,
      });

      expect(decoded, PanchangProfile.standard);
    });

    test('a newer calculation version survives round-trip unchanged', () {
      final decoded = PanchangProfile.fromJson(<String, dynamic>{
        'schema': PanchangProfile.schemaVersion,
        'calculationVersion': 99,
      });

      expect(decoded.calculationVersion, 99);
      expect(decoded.engineTag, 'panchang-v99');
    });

    test('blank timezone and rule-set ids normalize to null', () {
      final decoded = PanchangProfile.fromJson(<String, dynamic>{
        'timezoneId': '   ',
        'regionalRuleSetId': '',
      });

      expect(decoded.timezoneId, isNull);
      expect(decoded.regionalRuleSetId, isNull);
    });
  });

  group('PanchangProfile copyWith and equality', () {
    test('copyWith preserves unspecified fields', () {
      const original = PanchangProfile(timezoneId: 'Asia/Kolkata');
      final copy = original.copyWith(monthSystem: HinduMonthSystem.purnimant);

      expect(copy.monthSystem, HinduMonthSystem.purnimant);
      expect(copy.timezoneId, 'Asia/Kolkata');
      expect(copy.ayanamsa, original.ayanamsa);
    });

    test('copyWith can clear nullable fields', () {
      const original = PanchangProfile(
        timezoneId: 'Asia/Kolkata',
        regionalRuleSetId: 'bengali',
      );

      final cleared = original.copyWith(
        timezoneId: null,
        regionalRuleSetId: null,
      );

      expect(cleared.timezoneId, isNull);
      expect(cleared.regionalRuleSetId, isNull);
    });

    test('checkpoint set equality ignores insertion order', () {
      const a = FestivalObservancePolicy(
        checkpoints: {
          ObservanceCheckpoint.sunrise,
          ObservanceCheckpoint.pradosha,
        },
      );
      const b = FestivalObservancePolicy(
        checkpoints: {
          ObservanceCheckpoint.pradosha,
          ObservanceCheckpoint.sunrise,
        },
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a changed checkpoint set is not equal', () {
      const a = FestivalObservancePolicy(
        checkpoints: {ObservanceCheckpoint.sunrise},
      );
      const b = FestivalObservancePolicy(
        checkpoints: {ObservanceCheckpoint.moonrise},
      );

      expect(a, isNot(b));
    });

    test('a changed moonrise policy is not equal', () {
      const a = FestivalObservancePolicy();
      const b = FestivalObservancePolicy(
        moonrise: MoonrisePolicy.requireRise,
      );

      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
    });
  });

  group('PanchangProfile cacheKey', () {
    test('equal profiles produce equal keys', () {
      const a = PanchangProfile(timezoneId: 'Asia/Kolkata');
      const b = PanchangProfile(timezoneId: 'Asia/Kolkata');

      expect(a.cacheKey, b.cacheKey);
    });

    test('every output-affecting field changes the key', () {
      const base = PanchangProfile(timezoneId: 'Asia/Kolkata');

      final variants = <PanchangProfile>[
        base.copyWith(ayanamsa: SiderealMode.raman),
        base.copyWith(monthSystem: HinduMonthSystem.purnimant),
        base.copyWith(solarConvention: SolarEventConvention.apparentUpperLimb),
        base.copyWith(lunarLimb: LunarLimb.center),
        base.copyWith(lunarRefraction: LunarRefraction.none),
        base.copyWith(timezoneId: 'Asia/Tokyo'),
        base.copyWith(nodeConvention: NodeConvention.trueNode),
        base.copyWith(regionalRuleSetId: 'bengali'),
        base.copyWith(calculationVersion: 4),
        base.copyWith(
          observance: base.observance.copyWith(
            checkpoints: const {ObservanceCheckpoint.sunrise},
          ),
        ),
        base.copyWith(
          observance: base.observance.copyWith(kshaya: KshayaPolicy.strict),
        ),
        base.copyWith(
          observance: base.observance.copyWith(vriddhi: VriddhiPolicy.first),
        ),
        base.copyWith(
          observance: base.observance.copyWith(
            dominantTithi: DominantTithiPolicy.strict,
          ),
        ),
        base.copyWith(
          observance: base.observance.copyWith(
            nishita: NishitaPolicy.midpoint,
          ),
        ),
        base.copyWith(
          observance: base.observance.copyWith(
            moonrise: MoonrisePolicy.requireRise,
          ),
        ),
      ];

      final keys = <String>{base.cacheKey};
      for (final variant in variants) {
        expect(
          keys.add(variant.cacheKey),
          isTrue,
          reason: 'cacheKey collided for $variant',
        );
      }
    });

    test('engine tag carries the calculation version', () {
      const profile = PanchangProfile();

      expect(profile.engineTag, 'panchang-v$kPanchangCalculationVersion');
      expect(profile.cacheKey, startsWith('panchang-v3|'));
    });
  });
}
