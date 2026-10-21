import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Platform-specific initialization for mobile (Android/iOS)
Future<void> initPlatformFeatures() async {
  // Optimized Display Mode (90Hz/120Hz) - Android only
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      debugPrint('Error setting high refresh rate: $e');
    }
  }
}
