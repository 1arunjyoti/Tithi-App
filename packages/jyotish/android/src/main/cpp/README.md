# Swiss Ephemeris Android Build Setup

This directory is for the Swiss Ephemeris native Android build.

## Problem

The `jyotish` Flutter package requires the Swiss Ephemeris native library (`libswisseph.so`) for Android, but it's not included in the package.

## Solution

You need to download the Swiss Ephemeris C source files to enable native compilation.

### Step 1: Download Source Files

Run the following PowerShell commands to download the required files:

```powershell
cd d:\Projects\Tithi_Project\tithi\packages\jyotish\native\swisseph\swisseph-master

# Create src subdirectory
New-Item -ItemType Directory -Force -Path "src"
cd src

# Download Swiss Ephemeris source files from official GitHub repo
$baseUrl = "https://raw.githubusercontent.com/aloistr/swisseph/master/"
$files = @(
    "swecl.c", "swedate.c", "swedate.h", "swedll.h", "swehel.c",
    "swehouse.c", "swehouse.h", "swejpl.c", "swejpl.h",
    "swemmoon.c", "swemplan.c", "swemptab.h", "swenut2000a.h",
    "sweodef.h", "sweph.c", "sweph.h", "swephexp.h", "swephlib.c", "swephlib.h"
)

foreach ($file in $files) {
    Write-Host "Downloading $file..."
    Invoke-WebRequest -Uri "$baseUrl$file" -OutFile $file
}

Write-Host "All files downloaded successfully!"
```

### Step 2: Ensure NDK is Installed

The Android NDK is required for native compilation. You can install it via Android Studio:

1. Open Android Studio
2. Go to Tools > SDK Manager
3. Click "SDK Tools" tab
4. Check "NDK (Side by side)"
5. Click "Apply"

Or install via command line:

```powershell
sdkmanager --install "ndk;25.2.9519653"
```

### Step 3: Rebuild the Flutter App

After downloading the source files:

```powershell
cd d:\Projects\Tithi_Project\tithi
flutter clean
flutter pub get
flutter run
```

## Alternative: Use Pre-compiled Libraries

If you prefer not to compile from source, you can download pre-built `.so` files:

1. Go to https://github.com/krymlov/swe-android-lib/releases
2. Download the latest release
3. Extract and copy the `.so` files to:
   - `packages/jyotish/android/src/main/jniLibs/arm64-v8a/libswisseph.so`
   - `packages/jyotish/android/src/main/jniLibs/armeabi-v7a/libswisseph.so`
   - `packages/jyotish/android/src/main/jniLibs/x86_64/libswisseph.so`

Note: You may need to rename the files from `libswe-*.so` to `libswisseph.so`.
