// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanSessionModelAdapter extends TypeAdapter<ScanSessionModel> {
  @override
  final int typeId = 1;

  @override
  ScanSessionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanSessionModel(
      id: fields[0] as String,
      imagePaths: (fields[1] as List).cast<String>(),
      createdAt: fields[2] as DateTime,
      isCompleted: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ScanSessionModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.imagePaths)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanSessionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
