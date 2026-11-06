import 'package:jyotish/jyotish.dart';
import 'package:test/test.dart';

void main() {
  group('CalculationFlags', () {
    const defaultFlags = CalculationFlags();

    test('default flags keep the historical manual sidereal path', () {
      expect(defaultFlags.toSwissEphFlag() & SwissEphConstants.sidereal, 0);
      expect(defaultFlags.useTropical, isFalse);
      expect(defaultFlags.useNativeSidereal, isFalse);
    });

    test('native sidereal sets SEFLG_SIDEREAL', () {
      final native = CalculationFlags.nativeSidereal(SiderealMode.lahiri);

      expect(
        native.toSwissEphFlag() & SwissEphConstants.sidereal,
        SwissEphConstants.sidereal,
      );
      expect(native.useTropical, isFalse);
    });

    test('value equality includes every calculation input', () {
      const first = CalculationFlags(
        siderealMode: SiderealMode.krishnamurti,
        useTopocentric: true,
      );
      final second = first.copyWith();
      final otherMode = first.copyWith(siderealMode: SiderealMode.lahiri);
      final native = first.copyWith(useNativeSidereal: true);

      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
      expect(first, isNot(equals(otherMode)));
      expect(first, isNot(equals(native)));
    });
  });

  group('SiderealMode identifiers', () {
    test('name is the stable enum identifier, label is display text', () {
      expect(SiderealMode.lahiri.name, 'lahiri');
      expect(SiderealMode.lahiri.label, 'Lahiri');
      expect(
        SiderealMode.lahiri.persistenceKey,
        SwissEphConstants.sidmLahiri,
      );
    });

    test('label changes cannot change the persisted integer', () {
      for (final mode in SiderealMode.values) {
        expect(mode.persistenceKey, mode.constant);
        expect(mode.name, isNotEmpty);
      }
    });
  });
}
