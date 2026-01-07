import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/sankalpa_provider.dart';
import '../../models/sankalpa.dart';
import '../../theme/app_theme.dart';
import 'sankalpa_create_screen.dart';

class SankalpaListScreen extends ConsumerWidget {
  const SankalpaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sankalpas = ref.watch(sankalpaListProvider);
    final activeSankalpas = sankalpas.where((s) => !s.isCompleted).toList();
    final completedSankalpas = sankalpas.where((s) => s.isCompleted).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Sankalpas'),
          backgroundColor: Colors.transparent,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SankalpaCreateScreen()),
            );
          },
          label: const Text('New Intention'),
          icon: const Icon(Icons.add),
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
                  ? 'No completed intentions yet'
                  : 'Start a new spiritual journey',
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
        return _SankalpaCard(sankalpa: sankalpa, isHistory: isHistory);
      },
    );
  }
}

class _SankalpaCard extends ConsumerWidget {
  final Sankalpa sankalpa;
  final bool isHistory;

  const _SankalpaCard({required this.sankalpa, required this.isHistory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    onSelected: (value) {
                      if (value == 'delete') {
                        ref
                            .read(sankalpaListProvider.notifier)
                            .deleteSankalpa(sankalpa.id);
                      } else if (value == 'toggle') {
                        ref
                            .read(sankalpaListProvider.notifier)
                            .toggleCompletion(sankalpa.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'toggle',
                        child: Text('Mark Complete/Incomplete'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
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
                          'Day ${sankalpa.currentDayNumber} of ${sankalpa.durationDays}',
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
                        ? 'Done for today'
                        : 'Mark today as done',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Reminder: ${TimeOfDay(hour: sankalpa.reminderHour, minute: sankalpa.reminderMinute).format(context)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ] else ...[
              Text(
                'Completed on ${DateFormat.yMMMd().format(sankalpa.endDate ?? DateTime.now())}',
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
