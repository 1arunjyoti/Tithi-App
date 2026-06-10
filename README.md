# Tithi - Vedic Calendar App

**Tithi** is a modern, privacy-focused Vedic Calendar (Panchang) application built with Flutter. It provides accurate daily Panchang data, moon phases, and festival information based on your precise location, all without relying on Google Play Services.

## 🌟 Key Features

- **Accurate Panchang**: Daily Tithi, Nakshatra, Yoga, and Karana calculations derived from the Swiss Ephemeris.
- **Astronomical Visualization**:
  - **Solar System**: Interactive 3D-like view of the solar system with real-time planetary positions (Graha Gochar).
  - **Moon Phases**: Beautiful, animated representation of the current moon phase.
  - **Eclipses**: Track upcoming Solar and Lunar eclipses.
- **Spiritual Tools**:
  - **Sankalpa**: Create, track, and get reminders for your spiritual intentions and vows.
  - **Daily Wisdom**: Daily Shlokas and quotes with translations to start your day with positivity.
  - **Temple Finder**: Locate nearby temples with an interactive map.
- **Theme Support**:
  - **Auto**: Automatically switches between Day (Shukla) and Night (Pure Dark) modes.
  - **Shukla (Light)**: Vibrant orange and gold aesthetic representing the waxing moon.
  - **Pure Dark (Dark)**: Professional, OLED-black dark mode with gold accents for maximum readability and battery saving.
  - **Krishna (Cyber)**: Unique deep purple/neon aesthetic representing the waning moon.
- **FOSS & Privacy First**:
  - **Offline First**: Works completely offline using local Swiss Ephemeris data.
  - **No GMS Dependency**: Uses Android's native `LocationManager` and `OpenStreetMap` (Nominatim) for geolocation.
- **Notifications**: Daily Tithi and Sankalpa reminders scheduled locally.
- **Location Aware**: Precise calculations for your current city, with a manual "Home Location" picker.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **State Management**: [Riverpod](https://riverpod.dev/)
- **Local Storage**: [Hive](https://pub.dev/packages/hive)
- **Astronomy Engine**: [Swiss Ephemeris](https://www.astro.com/swisseph/) (via custom Dart FFI bindings)
- **Geolocation**: [geolocator](https://pub.dev/packages/geolocator) (Device GPS) + [nominatim_geocoding](https://pub.dev/packages/nominatim_geocoding) (Reverse Geocoding)
- **Maps**: [flutter_map](https://pub.dev/packages/flutter_map) (OpenStreetMap)
- **Notifications**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- **Sharing**: [share_plus](https://pub.dev/packages/share_plus)
- **Animations**: [lottie](https://pub.dev/packages/lottie)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (v3.10.4 or higher)
- Dart SDK (v3.0.0 or higher)
- Android Studio / VS Code with Flutter extensions
- NDK (for compiling Swiss Ephemeris bindings)

### Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/yourusername/tithi.git
   cd tithi
   ```

2. **Install Dependencies**:

   ```bash
   flutter pub get
   ```

3. **Prepare Assets**:
   Ensure the Swiss Ephemeris data files (`*.se1`) are present in `assets/ephe/`.

4. **Run the App**:

   ```bash
   flutter run
   ```

### Release Build With Auto-Bump

Use the wrapper script to increment the build number in `pubspec.yaml` and then build the release APK:

```powershell
.\build_release.ps1
```

## 📁 Project Structure

```bash
lib/
├── main.dart                 # Entry point, App initialization
├── theme/                    # Theme definitions (AppTheme, Colors)
├── screens/
│   ├── home_screen.dart      # Main dashboard (Panchang, Daily Quote)
│   ├── sankalpa/             # Sankalpa (Intention) feature screens
│   ├── solar_system_screen.dart   # Interactive Solar System visualization
│   ├── moon_phases_screen.dart    # Detailed moon phase view
│   ├── temple_map_screen.dart     # Nearby temple finder
│   ├── settings_screen.dart  # App settings
│   └── location_picker_screen.dart # Map-based location picker
│   └── eclipse_screen.dart      # Eclipse calendar
├── widgets/
│   ├── calendar_widget.dart  # Custom calendar UI
│   ├── daily_quote_widget.dart    # Daily wisdom card
│   ├── moon_animation_widget.dart # Lottie-based moon animations
│   └── common/               # Reusable UI components
├── providers/                # Riverpod state providers
│   ├── location_provider.dart     # Location management
│   ├── theme_provider.dart        # Theme switching logic
│   └── ...
├── services/                 # Backend logic
│   ├── location_service.dart      # Geolocation & Geocoding
│   ├── notification_service.dart  # Local notifications
│   ├── share_service.dart         # Feature sharing logic
│   └── shloka_service.dart        # Daily data fetching
├── models/                   # Data models (Festival, Shloka, Sankalpa)
└── packages/
    └── jyotish/              # Custom FFI bindings for Swiss Ephemeris
```
