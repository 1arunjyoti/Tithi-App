/// Central registry for all Hive type IDs used in the application.
///
/// Adding a new type? Pick the next available ID from the gap list below,
/// register it here, and use the constant in your `@HiveType(typeId: ...)`.
///
/// Current assignments:
///   0  [Festival]
///   1  [NameRegional]
///   2  [PanchangRules]
///   3  [TithiRule]
///   4  [Purpose]
///   5  [DateRange]
///   6  [FestivalCategory]
///   7  (available)
///   8  (available)
///   9  (available)
///  10  [Sankalpa]
abstract class HiveTypeIds {
  HiveTypeIds._(); // prevent instantiation

  /// [Festival]
  static const int festival = 0;

  /// [NameRegional]
  static const int nameRegional = 1;

  /// [PanchangRules]
  static const int panchangRules = 2;

  /// [TithiRule]
  static const int tithiRule = 3;

  /// [Purpose]
  static const int purpose = 4;

  /// [DateRange]
  static const int dateRange = 5;

  /// [FestivalCategory]
  static const int festivalCategory = 6;

  /// [Sankalpa]
  static const int sankalpa = 10;
}
