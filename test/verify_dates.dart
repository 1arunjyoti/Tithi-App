// ignore_for_file: avoid_redundant_argument_values, avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/services/panchang/panchang_service_native.dart';
import 'package:tithi/services/sunrise_calculator.dart';

void main() {
  test('verify 2026 dates', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final service = PanchangService();
    await service.init();

    final festivals = [
      const Festival(
        id: "parashurama_jayanti",
        name: "Parashurama Jayanti",
        category: "major",
        nameRegional: NameRegional(nameEnglish: "Parashurama Jayanti"),
        visuals: Visuals(),
        purpose: Purpose(description: ""),
        panchangRules: PanchangRules(
          masa: "Vaishakha",
          paksha: "Shukla",
          tithi: 3,
          conditions: "Tritiya",
        ),
        rituals: Rituals(steps: []),
        media: Media(),
      ),
      const Festival(
        id: "ganesh_chaturthi",
        name: "Ganesh Chaturthi",
        category: "major",
        nameRegional: NameRegional(nameEnglish: "Ganesh Chaturthi"),
        visuals: Visuals(),
        purpose: Purpose(description: ""),
        panchangRules: PanchangRules(
          masa: "Bhadrapada",
          paksha: "Shukla",
          tithi: 4,
          conditions: "Chaturthi",
        ),
        rituals: Rituals(steps: []),
        media: Media(),
      ),
      const Festival(
        id: "vijayadashami",
        name: "Vijayadashami",
        category: "major",
        nameRegional: NameRegional(nameEnglish: "Vijayadashami"),
        visuals: Visuals(),
        purpose: Purpose(description: ""),
        panchangRules: PanchangRules(
          masa: "Ashwin",
          paksha: "Shukla",
          tithi: 10,
          conditions: "Dashami",
        ),
        rituals: Rituals(steps: []),
        media: Media(),
      ),
      const Festival(
        id: "maha_shivaratri",
        name: "Maha Shivaratri",
        category: "major",
        nameRegional: NameRegional(nameEnglish: "Maha Shivaratri"),
        visuals: Visuals(),
        purpose: Purpose(description: ""),
        panchangRules: PanchangRules(
          masa: "Phalguna",
          paksha: "Krishna",
          tithi: 14,
          conditions: "Chaturdashi",
        ),
        rituals: Rituals(steps: []),
        media: Media(),
      ),
    ];

    Future<void> testDate(DateTime date) async {
      const lat = 28.6139;
      const lon = 77.2090;

      final sunriseTime = SunriseCalculator.calculateSunriseIST(
        date: date,
        latitude: lat,
        longitude: lon,
      );

      final sunsetTime = SunriseCalculator.calculateSunsetIST(
        date: date,
        latitude: lat,
        longitude: lon,
      );

      final nextSunriseTime = SunriseCalculator.calculateSunriseIST(
        date: date.add(const Duration(days: 1)),
        latitude: lat,
        longitude: lon,
      );

      final madhyahnaTime = sunriseTime.add(
        Duration(minutes: sunsetTime.difference(sunriseTime).inMinutes ~/ 2),
      );
      final aparahnaTime = sunriseTime.add(
        Duration(
          minutes: sunsetTime.difference(sunriseTime).inMinutes * 3 ~/ 4,
        ),
      );
      final nishitaTime = sunsetTime.add(
        Duration(
          minutes: nextSunriseTime.difference(sunsetTime).inMinutes ~/ 2,
        ),
      );

      final rawTithi = await service.calculateTithi(
        sunriseTime,
        latitude: lat,
        longitude: lon,
      );
      final masa = await service.calculateMasa(
        sunriseTime,
        rawTithi,
        latitude: lat,
        longitude: lon,
      );

      final rawTithiMadhyahna = await service.calculateTithi(
        madhyahnaTime,
        latitude: lat,
        longitude: lon,
      );
      final rawTithiAparahna = await service.calculateTithi(
        aparahnaTime,
        latitude: lat,
        longitude: lon,
      );
      final rawTithiNishita = await service.calculateTithi(
        nishitaTime,
        latitude: lat,
        longitude: lon,
      );

      final data = PanchangData.fromRawTithi(
        date: date,
        rawTithi: rawTithi,
        masa: masa,
        allFestivals: festivals,
        monthSystem: HinduMonthSystem.purnimant, // or amanta based on config
        sunrise: sunriseTime,
        sunset: sunsetTime,
        rawTithiMadhyahna: rawTithiMadhyahna,
        rawTithiAparahna: rawTithiAparahna,
        rawTithiNishita: rawTithiNishita,
      );

      if (date.month == 10 && (date.day == 20 || date.day == 21)) {
        print(
          "Oct ${date.day} - Sunrise Tithi: $rawTithi, Aparahna Tithi: $rawTithiAparahna",
        );
      }

      if (data.festivals.isNotEmpty) {
        print("Found festivals on $date:");
        for (var f in data.festivals) {
          print("  - ${f.name}");
        }
      }
    }

    // Parashurama Jayanti dates: Apr 19 and 20
    await testDate(DateTime(2026, 4, 19));
    await testDate(DateTime(2026, 4, 20));

    // Ganesh Chaturthi dates: Sep 14 and 15
    await testDate(DateTime(2026, 9, 14));
    await testDate(DateTime(2026, 9, 15));

    // Vijayadashami dates: Oct 20 and 21
    await testDate(DateTime(2026, 10, 20));
    await testDate(DateTime(2026, 10, 21));

    // Maha Shivaratri dates: Feb 15 and 16
    await testDate(DateTime(2026, 2, 15));
    await testDate(DateTime(2026, 2, 16));
  });
}
