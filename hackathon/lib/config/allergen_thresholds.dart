/// Configuration for allergen risk score thresholds
/// These values determine the risk level classification
class AllergenThresholds {
  // High risk threshold - above this is considered ALLERGIC
  static const double highRisk = 0.9;

  // Medium risk threshold - between this and highRisk is MAYBE
  static const double mediumRisk = 0.5;

  // Low risk threshold - any warning above 0.0 is at least MAYBE
  static const double lowRisk = 0.0;

  /// Get risk level based on score
  /// Returns: 'allergic', 'maybe', or 'safe'
  static String getRiskLevel(double score) {
    if (score >= highRisk) {
      return 'allergic';
    } else if (score >= mediumRisk) {
      return 'maybe';
    } else if (score > lowRisk) {
      return 'maybe'; // Any warning is at least maybe
    } else {
      return 'safe';
    }
  }
}
