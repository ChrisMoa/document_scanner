import 'package:hive/hive.dart';

part 'document_model.g.dart';

@HiveType(typeId: 0)
class DocumentModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<String> imagePaths;

  @HiveField(3)
  String? pdfPath;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  bool isUploaded;

  @HiveField(7)
  String? cloudUrl;

  @HiveField(8)
  bool isEncrypted;

  @HiveField(9)
  String? encryptionKeyId;

  @HiveField(10)
  String? storageLocation;

  @HiveField(11)
  bool isDownloaded;

  DocumentModel({
    required this.id,
    required this.name,
    this.imagePaths = const [],
    this.pdfPath,
    required this.createdAt,
    required this.updatedAt,
    this.isUploaded = false,
    this.cloudUrl,
    this.isEncrypted = false,
    this.encryptionKeyId,
    this.storageLocation,
    this.isDownloaded = false,
  });

  DocumentModel copyWith({
    String? id,
    String? name,
    List<String>? imagePaths,
    String? pdfPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isUploaded,
    String? cloudUrl,
    bool? isEncrypted,
    String? encryptionKeyId,
    String? storageLocation,
    bool? isDownloaded,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePaths: imagePaths ?? this.imagePaths,
      pdfPath: pdfPath ?? this.pdfPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isUploaded: isUploaded ?? this.isUploaded,
      cloudUrl: cloudUrl ?? this.cloudUrl,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      encryptionKeyId: encryptionKeyId ?? this.encryptionKeyId,
      storageLocation: storageLocation ?? this.storageLocation,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePaths': imagePaths,
      'pdfPath': pdfPath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isUploaded': isUploaded,
      'cloudUrl': cloudUrl,
      'isEncrypted': isEncrypted,
      'encryptionKeyId': encryptionKeyId,
      'storageLocation': storageLocation,
      'isDownloaded': isDownloaded,
    };
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      name: json['name'],
      imagePaths: List<String>.from(json['imagePaths']),
      pdfPath: json['pdfPath'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isUploaded: json['isUploaded'] ?? false,
      cloudUrl: json['cloudUrl'],
      isEncrypted: json['isEncrypted'] ?? false,
      encryptionKeyId: json['encryptionKeyId'],
      storageLocation: json['storageLocation'],
      isDownloaded: json['isDownloaded'] ?? false,
    );
  }
}
