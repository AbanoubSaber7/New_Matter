// lib/models/risk_assessment.dart

/// Risk levels in the application
enum RiskLevel {
  /// No risk - Normal message
  low,
  
  /// Low risk - May indicate mild anxiety or stress
  medium,
  
  /// High risk - Contains dangerous words or signals of self-harm
  high,
  
  /// Critical risk - Contains clear signals of suicide or immediate harm
  critical,
}

/// Risk analysis results model
class RiskAssessment {
  /// Detected risk level
  final RiskLevel level;
  
  /// Analysis confidence score (0-100)
  final double confidence;
  
  /// Reason for classification
  final String reason;
  
  /// Detected keywords
  final List<String> detectedKeywords;
  
  /// Suggested action recommendations
  final List<String> recommendations;
  
  /// Time of analysis
  final DateTime timestamp;
  
  /// Original message text
  final String originalText;

  RiskAssessment({
    required this.level,
    required this.confidence,
    required this.reason,
    required this.detectedKeywords,
    required this.recommendations,
    required this.originalText,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a modified copy of RiskAssessment
  RiskAssessment copyWith({
    RiskLevel? level,
    double? confidence,
    String? reason,
    List<String>? detectedKeywords,
    List<String>? recommendations,
    DateTime? timestamp,
    String? originalText,
  }) {
    return RiskAssessment(
      level: level ?? this.level,
      confidence: confidence ?? this.confidence,
      reason: reason ?? this.reason,
      detectedKeywords: detectedKeywords ?? this.detectedKeywords,
      recommendations: recommendations ?? this.recommendations,
      originalText: originalText ?? this.originalText,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Convert RiskAssessment to a map for saving in Firestore
  Map<String, dynamic> toMap() {
    return {
      'level': level.toString(),
      'confidence': confidence,
      'reason': reason,
      'detectedKeywords': detectedKeywords,
      'recommendations': recommendations,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create RiskAssessment from a Firestore map
  factory RiskAssessment.fromMap(Map<String, dynamic> map) {
    return RiskAssessment(
      level: RiskLevel.values.firstWhere(
        (e) => e.toString() == map['level'],
        orElse: () => RiskLevel.low,
      ),
      confidence: (map['confidence'] as num).toDouble(),
      reason: map['reason'] ?? '',
      detectedKeywords: List<String>.from(map['detectedKeywords'] ?? []),
      recommendations: List<String>.from(map['recommendations'] ?? []),
      originalText: map['originalText'] ?? '',
      timestamp: map['timestamp'] != null 
        ? DateTime.parse(map['timestamp']) 
        : DateTime.now(),
    );
  }
}
