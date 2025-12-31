class AllergenThresholds {
  static const double highRisk = 0.9;

  static const double mediumRisk = 0.5;

  static const double lowRisk = 0.0;

  static String getRiskLevel(double score) {
    if (score >= highRisk) {
      return 'allergic';
    } else if (score >= mediumRisk) {
      return 'maybe';
    } else if (score > lowRisk) {
      return 'maybe';
    } else {
      return 'safe';
    }
  }
}
