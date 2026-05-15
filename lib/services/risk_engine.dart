import '../models/risk_assessment.dart';

class RiskEngine {
  static const List<String> criticalKeywords = [
    'انتحار', 'أقتل نفسي', 'أنهي حياتي', 'أذبح نفسي', 'أنتحر', 'انتحاري', 'نفسي تموت', 'عايز أموت',
    'suicide', 'kill myself', 'end my life', 'want to die', 'die', 'إنهاء حياتي', 'انهاء حياتي', 'بنهي حياتي',
    'هخلص على نفسي', 'قررت أنتحر', 'وداعاً للجميع', 'مش هتشوفوني تاني', 'خلصت خلاص',
    'goodbye world', 'final message', 'last day', 'kill me', 'suicidal thoughts'
  ];

  static const List<String> highKeywords = [
    'تعبت من الحياة', 'كرهت نفسي', 'وجع كبير', 'مكتئب جدا', 'مخفوق',
    'depression', 'depressed', 'self harm', 'hurt myself', 'hopeless',
    'بقطع شراييني', 'عايز أختفي', 'كرهت كل حاجة', 'مفيش أمل', 'أنا فاشل', 'الكل بيكرهني', 'مش قادر أعيش',
    'i hate myself', 'worthless', 'cutting', 'no reason to live', 'misery', 'suffering'
  ];
  static const List<String> mediumKeywords = [
    'مضغوط',
    'قلقان',
    'متوتر',
    'حاسس بالوحدة',
    'مش مرتاح',
    'زعلان',
    'تعبان نفسيا',
    'خايف',
    'مش قادر',
    'مخنوق',
    'زهقان',
    'تايه',
    'وحيد',
    'مش عارف أعمل إيه',
    'stressed',
    'anxious',
    'tense',
    'lonely',
    'sad',
    'scared',
    'exhausted',
    'overwhelmed',
    'feeling down',
    'unhappy',
    'restless'
  ];
  static bool _fuzzyMatch(String text, String keyword) {
    int matchCount = 0;

    List<String> words = keyword.split(" ");

    for (var word in words) {
      if (text.contains(word)) {
        matchCount++;
      }
    }

    return matchCount >= (words.length / 2);
  }
static RiskAssessment analyzeText(String text) {
  String lowerText = text.toLowerCase();

  int score = 0;
  List<String> foundKeywords = [];

  for (var word in criticalKeywords) {
    if (lowerText.contains(word) || _fuzzyMatch(lowerText, word)) {
      score += 100;
      foundKeywords.add(word);
    }
  }

  for (var word in highKeywords) {
    if (lowerText.contains(word)) {
      score += 50;
      foundKeywords.add(word);
    }
  }
  for (var word in mediumKeywords) {
    if (lowerText.contains(word) || _fuzzyMatch(lowerText, word)) {
      score += 20;
      foundKeywords.add(word);
    }
  }

  RiskLevel level;
  String reason;

  if (score >= 100) {
    level = RiskLevel.critical;
    reason = "Critical risk - Immediate intervention required";
  } else if (score >= 50) {
    level = RiskLevel.high;
    reason = "High risk - Strong psychological pressure";
  } else if (score >= 20) {
    level = RiskLevel.medium;
    reason = "Medium psychological pressure";
  } else {
    level = RiskLevel.low;
    reason = "Normal message";
  }

  return RiskAssessment(
    level: level,
    confidence: score > 100 ? 100 : score.toDouble(),
    reason: reason,
    detectedKeywords: foundKeywords,
    recommendations: level == RiskLevel.critical
        ? [
            "Contact a trusted person immediately",
            "Use mental health support numbers",
            "Do not stay alone"
          ]
        : level == RiskLevel.high
            ? [
                "Talk to someone you trust",
                "Seek psychological support",
              ]
            : level == RiskLevel.medium
                ? [
                    "Take a break",
                    "Talk about your feelings",
                  ]
                : [
                    "Keep taking care of yourself"
                  ],
    originalText: text,
  );
}
}