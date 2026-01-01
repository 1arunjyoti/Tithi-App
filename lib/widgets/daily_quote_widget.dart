import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/shloka.dart';
import '../services/shloka_service.dart';
import '../theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';

// Provider to get today's shloka
final dailyShlokaProvider = FutureProvider<Shloka?>((ref) async {
  final service = ShlokaService();
  await service.init();
  return service.getShlokaForToday();
});

// UI State provider for collapse/expand
// Using autoDispose so it resets when leaving the screen/rebuilding
final quoteExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);

class DailyQuoteWidget extends ConsumerWidget {
  const DailyQuoteWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shlokaAsync = ref.watch(dailyShlokaProvider);
    final isExpanded = ref.watch(quoteExpandedProvider);

    return shlokaAsync.when(
      data: (shloka) {
        if (shloka == null) return const SizedBox.shrink();

        return Container(
          // Match CalendarWidget margin exactly (horizontal 12)
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: AppTheme.glassmorphism(
            context: context,
            opacity: 0.1,
            borderRadius: 24,
            ref: ref,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header & Share
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 16, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 18,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Daily Wisdom',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),

                    // Share Button
                    IconButton(
                      icon: Icon(
                        Icons.share_rounded,
                        size: 18,
                        color: context.colors.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        final text = isExpanded
                            ? '${shloka.text}\n\n${shloka.translation}\n- ${shloka.source}\n\nShared via Tithi App'
                            : '${shloka.text}\n- ${shloka.source}\n\nShared via Tithi App';
                        SharePlus.instance.share(
                          ShareParams(text: text, subject: 'Daily Wisdom'),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Share',
                    ),
                  ],
                ),
              ),

              //const Divider(height: 2),

              // Content Area
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
                child: Column(
                  children: [
                    // Sanskrit Text (Always visible)
                    Text(
                      shloka.text,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.martel(
                        fontSize: 18,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),

                    const SizedBox(height: 2),

                    // Collapsible Translation
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Column(
                          children: [
                            Text(
                              shloka.translation,
                              textAlign: TextAlign.center,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colors.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Source shown when expanded
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "— ${shloka.source}",
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),

                    // Toggle Button
                    GestureDetector(
                      onTap: () {
                        // Toggle state via provider
                        ref.read(quoteExpandedProvider.notifier).state =
                            !isExpanded;
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: context.colors.primary.withValues(alpha: 0.6),
                          size: 28, // Made slightly larger for visibility
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
