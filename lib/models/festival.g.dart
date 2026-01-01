// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'festival.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FestivalAdapter extends TypeAdapter<Festival> {
  @override
  final int typeId = 0;

  @override
  Festival read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Festival(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as String,
      nameRegional: fields[3] as NameRegional,
      visuals: fields[4] as Visuals,
      purpose: fields[5] as Purpose,
      panchangRules: fields[6] as PanchangRules,
      rituals: fields[7] as Rituals,
      media: fields[8] as Media,
    );
  }

  @override
  void write(BinaryWriter writer, Festival obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.nameRegional)
      ..writeByte(4)
      ..write(obj.visuals)
      ..writeByte(5)
      ..write(obj.purpose)
      ..writeByte(6)
      ..write(obj.panchangRules)
      ..writeByte(7)
      ..write(obj.rituals)
      ..writeByte(8)
      ..write(obj.media);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FestivalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NameRegionalAdapter extends TypeAdapter<NameRegional> {
  @override
  final int typeId = 1;

  @override
  NameRegional read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NameRegional(
      nameSanskrith: fields[0] as String?,
      nameEnglish: fields[1] as String,
      nameHindi: fields[2] as String?,
      nameBengali: fields[3] as String?,
      nameTelugu: fields[4] as String?,
      nameKannada: fields[5] as String?,
      nameTamil: fields[6] as String?,
      nameMalayalam: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NameRegional obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.nameSanskrith)
      ..writeByte(1)
      ..write(obj.nameEnglish)
      ..writeByte(2)
      ..write(obj.nameHindi)
      ..writeByte(3)
      ..write(obj.nameBengali)
      ..writeByte(4)
      ..write(obj.nameTelugu)
      ..writeByte(5)
      ..write(obj.nameKannada)
      ..writeByte(6)
      ..write(obj.nameTamil)
      ..writeByte(7)
      ..write(obj.nameMalayalam);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NameRegionalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VisualsAdapter extends TypeAdapter<Visuals> {
  @override
  final int typeId = 2;

  @override
  Visuals read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Visuals(
      image: fields[0] as String,
      themeColor: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Visuals obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.image)
      ..writeByte(1)
      ..write(obj.themeColor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisualsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PurposeAdapter extends TypeAdapter<Purpose> {
  @override
  final int typeId = 3;

  @override
  Purpose read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Purpose(
      description: fields[0] as String,
      additionalDescription: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Purpose obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.description)
      ..writeByte(1)
      ..write(obj.additionalDescription);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurposeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PanchangRulesAdapter extends TypeAdapter<PanchangRules> {
  @override
  final int typeId = 4;

  @override
  PanchangRules read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PanchangRules(
      masa: fields[0] as String,
      paksha: fields[1] as String,
      tithi: fields[2] as int,
      conditions: fields[3] as String,
      recurring: fields[4] as bool,
      solarDate: fields[5] as String?,
      weekday: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PanchangRules obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.masa)
      ..writeByte(1)
      ..write(obj.paksha)
      ..writeByte(2)
      ..write(obj.tithi)
      ..writeByte(3)
      ..write(obj.conditions)
      ..writeByte(4)
      ..write(obj.recurring)
      ..writeByte(5)
      ..write(obj.solarDate)
      ..writeByte(6)
      ..write(obj.weekday);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PanchangRulesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RitualsAdapter extends TypeAdapter<Rituals> {
  @override
  final int typeId = 5;

  @override
  Rituals read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Rituals(
      steps: (fields[0] as List).cast<String>(),
      mantra: fields[1] as String,
      fasting: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Rituals obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.steps)
      ..writeByte(1)
      ..write(obj.mantra)
      ..writeByte(2)
      ..write(obj.fasting);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RitualsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MediaAdapter extends TypeAdapter<Media> {
  @override
  final int typeId = 6;

  @override
  Media read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Media(
      audioStotra: fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Media obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.audioStotra);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
