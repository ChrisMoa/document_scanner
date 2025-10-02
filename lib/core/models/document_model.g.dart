// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DocumentModelAdapter extends TypeAdapter<DocumentModel> {
  @override
  final int typeId = 0;

  @override
  DocumentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DocumentModel(
      id: fields[0] as String,
      name: fields[1] as String,
      imagePaths: (fields[2] as List).cast<String>(),
      pdfPath: fields[3] as String?,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      isUploaded: fields[6] as bool,
      cloudUrl: fields[7] as String?,
      isEncrypted: fields[8] as bool,
      encryptionKeyId: fields[9] as String?,
      storageLocation: fields[10] as String?,
      isDownloaded: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.imagePaths)
      ..writeByte(3)
      ..write(obj.pdfPath)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.isUploaded)
      ..writeByte(7)
      ..write(obj.cloudUrl)
      ..writeByte(8)
      ..write(obj.isEncrypted)
      ..writeByte(9)
      ..write(obj.encryptionKeyId)
      ..writeByte(10)
      ..write(obj.storageLocation)
      ..writeByte(11)
      ..write(obj.isDownloaded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
