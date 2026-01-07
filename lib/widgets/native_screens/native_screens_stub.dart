import 'package:flutter/material.dart';

// Stub classes for web - these screens are not available on web
// but we need placeholders to satisfy type checking

class SolarSystemScreen extends StatelessWidget {
  const SolarSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Solar System is not available on web')),
    );
  }
}

class EclipseScreen extends StatelessWidget {
  const EclipseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Eclipse screen is not available on web')),
    );
  }
}
