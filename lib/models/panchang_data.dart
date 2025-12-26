import 'festival.dart';

/// Panchang data for a specific date
class PanchangData {
  final DateTime date;
  final double rawTithi;
  final int tithiNumber;
  final String tithiName;
  final String paksha;
  final String masa;
  final List<Festival> festivals;

  const PanchangData({
    required this.date,
    required this.rawTithi,
    required this.tithiNumber,
    required this.tithiName,
    required this.paksha,
    this.masa = '',
    this.festivals = const [],
  });

  /// Check if this is Shukla Paksha (waxing moon)
  bool get isShukla => paksha == 'Shukla';

  /// Check if this is Krishna Paksha (waning moon)
  bool get isKrishna => paksha == 'Krishna';

  /// Check if there are any festivals on this day
  bool get hasFestivals => festivals.isNotEmpty;

  /// Get major festivals only
  List<Festival> get majorFestivals =>
      festivals.where((f) => f.category == 'major').toList();

  /// Get vrat (fasting) days only
  List<Festival> get vrats =>
      festivals.where((f) => f.category == 'vrat').toList();

  /// Create from raw tithi calculation
  factory PanchangData.fromRawTithi({
    required DateTime date,
    required double rawTithi,
    String masa = '',
    List<Festival> allFestivals = const [],
  }) {
    final tithiIndex = rawTithi.floor();

    // Determine paksha and tithi number
    String paksha;
    int tithiNumber;
    if (tithiIndex <= 15) {
      paksha = 'Shukla';
      tithiNumber = tithiIndex;
    } else {
      paksha = 'Krishna';
      tithiNumber = tithiIndex - 15;
    }

    // Get tithi name
    final tithiName = _getTithiName(tithiNumber);

    // Find matching festivals
    final matchingFestivals = allFestivals
        .where((f) => f.matchesTithi(paksha, tithiNumber, masa))
        .toList();

    return PanchangData(
      date: date,
      rawTithi: rawTithi,
      tithiNumber: tithiNumber,
      tithiName: tithiName,
      paksha: paksha,
      masa: masa,
      festivals: matchingFestivals,
    );
  }

  static String _getTithiName(int tithiNum) {
    const tithiNames = [
      '',
      'Pratipada',
      'Dwitiya',
      'Tritiya',
      'Chaturthi',
      'Panchami',
      'Shashthi',
      'Saptami',
      'Ashtami',
      'Navami',
      'Dashami',
      'Ekadashi',
      'Dwadashi',
      'Trayodashi',
      'Chaturdashi',
      'Purnima/Amavasya',
    ];
    if (tithiNum >= 1 && tithiNum <= 15) {
      return tithiNames[tithiNum];
    }
    return 'Unknown';
  }

  @override
  String toString() =>
      'PanchangData($date: $masa $paksha $tithiName, ${festivals.length} festivals)';
}
