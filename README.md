# Tithi - Vedic Calendar App

**Tithi** is a modern, privacy-focused Vedic Calendar (Panchang) application built with Flutter. It provides accurate daily Panchang data, moon phases, and festival information based on your precise location, all without relying on Google Play Services.

## 🌟 Key Features

- **Accurate Panchang**: Daily Tithi, Nakshatra, Yoga, and Karana calculations derived from the Swiss Ephemeris.
- **Theme Support**:
  - **Auto**: Automatically switches between Day (Shukla) and Night (Pure Dark) modes.
  - **Shukla (Light)**: Vibrant orange and gold aesthetic representing the waxing moon.
  - **Pure Dark (Dark)**: Professional, OLED-black dark mode with gold accents for maximum readability and battery saving.
  - **Krishna (Cyber)**: Unique deep purple/neon aesthetic representing the waning moon.
- **FOSS & Privacy First**:
  - **Offline First**: Works completely offline using local Swiss Ephemeris data.
  - **No GMS Dependency**: Uses Android's native `LocationManager` and `OpenStreetMap` (Nominatim) for geolocation, making it fully compatible with de-Googled Android (GrapheneOS, CalyxOS, LineageOS).
- **Notifications**: Daily Tithi reminders scheduled locally on your device.
- **Location Aware**: Moonrise, sunset, and Tithi timings are calculated precisely for your current city.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **State Management**: [Riverpod](https://riverpod.dev/)
- **Local Storage**: [Hive](https://pub.dev/packages/hive)
- **Astronomy Engine**: [Swiss Ephemeris](https://www.astro.com/swisseph/) (via custom Dart FFI bindings)
- **Geolocation**: [geolocator](https://pub.dev/packages/geolocator) (Device GPS) + [nominatim_geocoding](https://pub.dev/packages/nominatim_geocoding) (Reverse Geocoding)
- **Notifications**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (v3.10.4 or higher)
- Dart SDK (v3.0.0 or higher)
- Android Studio / VS Code with Flutter extensions
- NDK (for compiling Swiss Ephemeris bindings)

### Installation

1.  **Clone the repository**:

    ```bash
    git clone https://github.com/yourusername/tithi.git
    cd tithi
    ```

2.  **Install Dependencies**:

    ```bash
    flutter pub get
    ```

3.  **Prepare Assets**:
    Ensure the Swiss Ephemeris data files (`*.se1`) are present in `assets/ephe/`.

4.  **Run the App**:
    ```bash
    flutter run
    ```

## 📁 Project Structure

```
lib/
├── main.dart             # Entry point using Riverpod's ProviderScope
├── theme/               # Theme definitions (AppTheme, Colors)
├── screens/             # UI Screens (HomeScreen, SettingsScreen)
├── widgets/             # Reusable widgets (Calendar, EventList, AppDrawer)
├── providers/           # Riverpod state providers (Theme, Location, Panchang, Notifications)
└── packages/
    └── jyotish/         # Custom package for Swiss Ephemeris bindings
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
