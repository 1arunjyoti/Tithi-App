// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sankalpa.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SankalpaAdapter extends TypeAdapter<Sankalpa> {
  @override
  final int typeId = 10;

  @override
  Sankalpa read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sankalpa(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String,
      startDate: fields[3] as DateTime,
      durationDays: fields[4] as int,
      reminderHour: fields[6] as int,
      reminderMinute: fields[7] as int,
      isCompleted: fields[8] as bool,
      dailyCompletions: (fields[9] as List?)?.cast<DateTime>(),
    )..endDate = fields[5] as DateTime?;
  }

  @override
  void write(BinaryWriter writer, Sankalpa obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.durationDays)
      ..writeByte(5)
      ..write(obj.endDate)
      ..writeByte(6)
      ..write(obj.reminderHour)
      ..writeByte(7)
      ..write(obj.reminderMinute)
      ..writeByte(8)
      ..write(obj.isCompleted)
      ..writeByte(9)
      ..write(obj.dailyCompletions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SankalpaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
