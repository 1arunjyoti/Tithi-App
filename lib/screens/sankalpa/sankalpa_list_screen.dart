import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/sankalpa_provider.dart';
import '../../models/sankalpa.dart';
import '../../l10n/app_localizations.dart';
import '../../core/anim/press_scale.dart';
import '../../core/navigation/haptic_back_button.dart';
import '../../core/navigation/app_routes.dart';
import '../../theme/app_theme.dart';
import 'sankalpa_create_screen.dart';

class SankalpaListScreen extends ConsumerWidget {
  const SankalpaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sankalpas = ref.watch(sankalpaListProvider);
    final activeSankalpas = sankalpas.where((s) => !s.isCompleted).toList();
    final completedSankalpas = sankalpas.where((s) => s.isCompleted).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HapticBackButton(),
          title: Text(l10n.mySankalpas),
          backgroundColor: Colors.transparent,
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.active),
              Tab(text: l10n.completed),
            ],
          ),
        ),
        floatingActionButton: PressScale(
          child: FloatingActionButton.extended(
            onPressed: () {
              // Hierarchical drill: list → create form.
              AppRoutes.pushSharedX(context, const SankalpaCreateScreen());
            },
            label: Text(l10n.newIntention),
            icon: const Icon(Icons.add),
          ),
        ),
        body: Container(
          decoration: AppTheme.backgroundDecoration(context),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: TabBarView(
                children: [
                  _SankalpaList(sankalpas: activeSankalpas),
                  _SankalpaList(sankalpas: completedSankalpas, isHistory: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SankalpaList extends ConsumerWidget {
  final List<Sankalpa> sankalpas;
  final bool isHistory;

  const _SankalpaList({required this.sankalpas, this.isHistory = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (sankalpas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHistory ? Icons.history : Icons.spa,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              isHistory
                  ? l10n.noCompletedIntentionsYet
                  : l10n.startNewSpiritualJourney,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sankalpas.length,
      itemBuilder: (context, index) {
        final sankalpa = sankalpas[index];
        return _SankalpaCard(
          key: ValueKey('sankalpa_${sankalpa.id}_$index'),
          sankalpa: sankalpa,
          isHistory: isHistory,
        );
      },
    );
  }
}

class _SankalpaCard extends ConsumerWidget {
  final Sankalpa sankalpa;
  final bool isHistory;

  const _SankalpaCard({
    super.key,
    required this.sankalpa,
    required this.isHistory,
  });

  Future<bool> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteSankalpa),
        content: Text(l10n.deleteSankalpaMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final progress = sankalpa.currentDayNumber / sankalpa.durationDays;
    final clampedProgress = progress.clamp(0.0, 1.0);
    // final daysRemaining = sankalpa.daysRemaining;

    // Check if today is marked
    final now = DateTime.now();
    final todayMarked = sankalpa.dailyCompletions.any(
      (d) => d.year == now.year && d.month == now.month && d.day == now.day,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    sankalpa.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isHistory)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirmed = await _confirmDelete(context, l10n);
                        if (!confirmed) return;
                        await ref
                            .read(sankalpaListProvider.notifier)
                            .deleteSankalpa(sankalpa.id);
                      } else if (value == 'toggle') {
                        await ref
                            .read(sankalpaListProvider.notifier)
                            .toggleCompletion(sankalpa.id);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(l10n.markCompleteIncomplete),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          l10n.delete,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (sankalpa.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                sankalpa.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            if (!isHistory) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dayOf(
                            sankalpa.currentDayNumber,
                            sankalpa.durationDays,
                          ),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: clampedProgress,
                          borderRadius: BorderRadius.circular(4),
                          backgroundColor: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    onPressed: todayMarked
                        ? null
                        : () => ref
                              .read(sankalpaListProvider.notifier)
                              .markDailyProgress(sankalpa.id),
                    icon: Icon(
                      todayMarked ? Icons.check_circle : Icons.circle_outlined,
                    ),
                    tooltip: todayMarked
                        ? l10n.doneForToday
                        : l10n.markTodayAsDone,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.reminderAt(
                  TimeOfDay(
                    hour: sankalpa.reminderHour,
                    minute: sankalpa.reminderMinute,
                  ).format(context),
                ),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ] else ...[
              Text(
                l10n.completedOn(
                  DateFormat.yMMMd().format(sankalpa.endDate),
                ),
                style: TextStyle(
                  color: AppTheme.success(
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
