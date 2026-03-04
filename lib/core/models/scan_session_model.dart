import 'package:hive/hive.dart';

part 'scan_session_model.g.dart';

@HiveType(typeId: 1)
class ScanSessionModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  List<String> imagePaths;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  bool isCompleted;

  ScanSessionModel({
    required this.id,
    this.imagePaths = const [],
    required this.createdAt,
    this.isCompleted = false,
  });

  ScanSessionModel copyWith({
    String? id,
    List<String>? imagePaths,
    DateTime? createdAt,
    bool? isCompleted,
  }) {
    return ScanSessionModel(
      id: id ?? this.id,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePaths': imagePaths,
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory ScanSessionModel.fromJson(Map<String, dynamic> json) {
    return ScanSessionModel(
      id: json['id'],
      imagePaths: List<String>.from(json['imagePaths']),
      createdAt: DateTime.parse(json['createdAt']),
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

