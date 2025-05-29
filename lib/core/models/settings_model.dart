class DocumentProcessingSettings {
  final bool enableFiltering; // Master toggle for all filtering
  final double blackWhiteThreshold; // Threshold for black/white filter (0.0 - 1.0)
  final double sharpnessAmount; // Sharpening amount (0.0 - 3.0)
  final double sharpnessRadius; // Sharpening radius (0.5 - 3.0)
  final int sharpnessThreshold; // Sharpening threshold (0 - 10)
  final double contrastLevel; // Contrast enhancement (0.5 - 2.0)
  final double brightnessLevel; // Brightness adjustment (0.5 - 2.0)
  final double gammaCorrection; // Gamma correction (0.3 - 1.5)

  const DocumentProcessingSettings({
    this.enableFiltering = true,
    this.blackWhiteThreshold = 0.65,
    this.sharpnessAmount = 1.8,
    this.sharpnessRadius = 1.5,
    this.sharpnessThreshold = 1,
    this.contrastLevel = 1.3,
    this.brightnessLevel = 1.1,
    this.gammaCorrection = 0.85,
  });

  DocumentProcessingSettings copyWith({
    bool? enableFiltering,
    double? blackWhiteThreshold,
    double? sharpnessAmount,
    double? sharpnessRadius,
    int? sharpnessThreshold,
    double? contrastLevel,
    double? brightnessLevel,
    double? gammaCorrection,
  }) {
    return DocumentProcessingSettings(
      enableFiltering: enableFiltering ?? this.enableFiltering,
      blackWhiteThreshold: blackWhiteThreshold ?? this.blackWhiteThreshold,
      sharpnessAmount: sharpnessAmount ?? this.sharpnessAmount,
      sharpnessRadius: sharpnessRadius ?? this.sharpnessRadius,
      sharpnessThreshold: sharpnessThreshold ?? this.sharpnessThreshold,
      contrastLevel: contrastLevel ?? this.contrastLevel,
      brightnessLevel: brightnessLevel ?? this.brightnessLevel,
      gammaCorrection: gammaCorrection ?? this.gammaCorrection,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableFiltering': enableFiltering,
      'blackWhiteThreshold': blackWhiteThreshold,
      'sharpnessAmount': sharpnessAmount,
      'sharpnessRadius': sharpnessRadius,
      'sharpnessThreshold': sharpnessThreshold,
      'contrastLevel': contrastLevel,
      'brightnessLevel': brightnessLevel,
      'gammaCorrection': gammaCorrection,
    };
  }

  factory DocumentProcessingSettings.fromJson(Map<String, dynamic> json) {
    return DocumentProcessingSettings(
      enableFiltering: (json['enableFiltering'] as bool?) ?? true,
      blackWhiteThreshold: (json['blackWhiteThreshold'] as num?)?.toDouble() ?? 0.65,
      sharpnessAmount: (json['sharpnessAmount'] as num?)?.toDouble() ?? 1.8,
      sharpnessRadius: (json['sharpnessRadius'] as num?)?.toDouble() ?? 1.5,
      sharpnessThreshold: (json['sharpnessThreshold'] as int?) ?? 1,
      contrastLevel: (json['contrastLevel'] as num?)?.toDouble() ?? 1.3,
      brightnessLevel: (json['brightnessLevel'] as num?)?.toDouble() ?? 1.1,
      gammaCorrection: (json['gammaCorrection'] as num?)?.toDouble() ?? 0.85,
    );
  }

  @override
  String toString() {
    return 'DocumentProcessingSettings(enableFiltering: $enableFiltering, blackWhiteThreshold: $blackWhiteThreshold, sharpnessAmount: $sharpnessAmount, sharpnessRadius: $sharpnessRadius, sharpnessThreshold: $sharpnessThreshold, contrastLevel: $contrastLevel, brightnessLevel: $brightnessLevel, gammaCorrection: $gammaCorrection)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentProcessingSettings &&
        other.enableFiltering == enableFiltering &&
        other.blackWhiteThreshold == blackWhiteThreshold &&
        other.sharpnessAmount == sharpnessAmount &&
        other.sharpnessRadius == sharpnessRadius &&
        other.sharpnessThreshold == sharpnessThreshold &&
        other.contrastLevel == contrastLevel &&
        other.brightnessLevel == brightnessLevel &&
        other.gammaCorrection == gammaCorrection;
  }

  @override
  int get hashCode {
    return Object.hash(enableFiltering, blackWhiteThreshold, sharpnessAmount, sharpnessRadius, sharpnessThreshold, contrastLevel, brightnessLevel, gammaCorrection);
  }
}
