import 'package:flutter/material.dart';
import '../models/festival.dart';

class FestivalShareCard extends StatelessWidget {
  final Festival festival;

  const FestivalShareCard({super.key, required this.festival});

  @override
  Widget build(BuildContext context) {
    // Fixed dimensions for consistency - Instagram portrait ratio is good but maybe square is safer for generic sharing
    // Let's go with a nice portrait card: 1080x1920 logical pixels (scaled down by device)
    // Actually, usually we share the screenshot of what's rendered.
    // We will build a container that attempts to look "premium".

    return Container(
      width: 400, // Logical width for capture
      height: 600, // Logical height for capture
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1E2C), // Deep dark background
            Color(0xFF2D2D44),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background ornamental circles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon / Header
                const Icon(
                  Icons.auto_awesome, // Placeholder for festival icon
                  size: 64,
                  color: Colors.amber,
                ),
                const SizedBox(height: 32),

                // Festival Name
                Text(
                  festival.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily:
                        'Serif', // Use a serif font for elegance if available
                    letterSpacing: 1.2,
                  ),
                ),
                if (festival.nameHindi != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    festival.nameHindi!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Date/Tithi details
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    "${festival.paksha} ${festival.tithi != 0 ? '• Tithi ${festival.tithi}' : ''}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Description Quote
                Text(
                  festival.description,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const Spacer(),

                // Footer / Branding
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Tithi App",
                      style: TextStyle(
                        color: Colors.amber.withValues(alpha: 0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
