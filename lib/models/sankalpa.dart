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

  @HiveField(5)
  DateTime? endDate;

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
       dailyCompletions = dailyCompletions ?? [] {
    endDate = startDate.add(Duration(days: durationDays));
  }

  /// Returns the current day number (1-based) relative to start date
  int get currentDayNumber {
    final now = DateTime.now();
    final difference = now.difference(startDate).inDays;
    return difference + 1; // 1-based index
  }

  /// Returns total days remaining
  int get daysRemaining {
    return durationDays - currentDayNumber;
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
