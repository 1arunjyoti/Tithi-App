import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'sankalpa.g.dart';

@HiveType(typeId: 10)
class Sankalpa extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final DateTime startDate;

  @HiveField(4)
  final int durationDays;

  // endDate is now a derived getter (was @HiveField(5), kept in adapter for
  // backward-compatible reads). See sankalpa.g.dart.

  @HiveField(6)
  final int reminderHour;

  @HiveField(7)
  final int reminderMinute;

  @HiveField(8)
  final bool isCompleted;

  @HiveField(9)
  final List<DateTime> dailyCompletions;

  Sankalpa({
    String? id,
    required this.title,
    this.description = '',
    required this.startDate,
    required this.durationDays,
    this.reminderHour = 7, // Default 7 AM
    this.reminderMinute = 0,
    this.isCompleted = false,
    List<DateTime>? dailyCompletions,
  }) : id = id ?? const Uuid().v4(),
       dailyCompletions = dailyCompletions ?? [];

  /// The computed end date, always derived from [startDate] + [durationDays].
  /// Previously a mutable @HiveField(5); now a getter so it can never go stale.
  DateTime get endDate => startDate.add(Duration(days: durationDays));

  /// Returns the current day number (1-based) relative to start date.
  /// Both timestamps are normalised to midnight so the result is purely
  /// calendar-day based and does not depend on the time the sankalpa was
  /// created or the exact moment it is queried (BUG-4 fix).
  int get currentDayNumber {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return today.difference(start).inDays + 1; // 1-based index
  }

  /// Returns total days remaining (clamped to 0 so it never goes negative
  /// when the sankalpa has expired).
  int get daysRemaining {
    return (durationDays - currentDayNumber).clamp(0, durationDays);
  }

  /// Creates a copy with updated fields
  Sankalpa copyWith({
    String? title,
    String? description,
    DateTime? startDate,
    int? durationDays,
    int? reminderHour,
    int? reminderMinute,
    bool? isCompleted,
    List<DateTime>? dailyCompletions,
  }) {
    return Sankalpa(
      id: id, // ID cannot be changed
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      durationDays: durationDays ?? this.durationDays,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      isCompleted: isCompleted ?? this.isCompleted,
      dailyCompletions: dailyCompletions ?? this.dailyCompletions,
    );
  }
}
