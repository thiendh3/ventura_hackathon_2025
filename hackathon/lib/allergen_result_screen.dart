import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/translation_service.dart';
import 'config/allergen_thresholds.dart';

enum AllergenResultType {
  allergic, // Allergic
  safe,     // Safe
  maybe,    // Maybe
}

class AllergenResultScreen extends StatefulWidget {
  final AllergenResultType resultType;
  final List<String> ingredients;
  final String? imagePath;
  final List<Map<String, dynamic>>? healthWarnings;
  final Map<String, dynamic>? riskSummary;
  final List<String>? safeIngredients;
  final List<String>? allIngredients;

  const AllergenResultScreen({
    super.key,
    required this.resultType,
    required this.ingredients,
    this.imagePath,
    this.healthWarnings,
    this.riskSummary,
    this.safeIngredients,
    this.allIngredients,
  });

  @override
  State<AllergenResultScreen> createState() => _AllergenResultScreenState();
}

class _AllergenResultScreenState extends State<AllergenResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Scale animation
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Pulse animation (for allergic)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Shake animation (for maybe)
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticInOut),
    );

    // Start animations
    _fadeController.forward();
    _scaleController.forward();

    if (widget.resultType == AllergenResultType.allergic) {
      _pulseController.repeat(reverse: true);
    } else if (widget.resultType == AllergenResultType.maybe) {
      _shakeController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _shareResult() {
    String resultText = _getMainText();
    String subText = _getSubText();
    String ingredientsText = widget.ingredients.isNotEmpty
        ? '\n\nIngredients: ${widget.ingredients.join(', ')}'
        : '';

    String shareText = '$resultText\n$subText$ingredientsText\n\n#Safein #AllergenCheck';

    Clipboard.setData(ClipboardData(text: shareText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép kết quả! Bạn có thể chia sẻ ở bất kỳ đâu.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showIngredientDetails(Map<String, dynamic> warning) async {
    final riskScore = (warning['risk_score'] as num?)?.toDouble() ?? 0.0;
    final riskType = riskScore >= AllergenThresholds.highRisk ? AllergenResultType.allergic : AllergenResultType.maybe;
    // Translate ingredient for display
    final originalIngredient = warning['ingredient']?.toString() ?? 'Không xác định';
    final ingredient = await TranslationService().translateIngredient(originalIngredient);

    // Fields that need special handling (displayed separately)
    final specialFields = {'risk_score', 'ingredient', 'warning_type'};

    // Get all other fields dynamically
    final dynamicFields = <String, dynamic>{};
    warning.forEach((key, value) {
      if (!specialFields.contains(key) && value != null) {
        dynamicFields[key] = value;
      }
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getGradientStartForType(riskType),
                _getGradientEndForType(riskType),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ingredient, // Already translated
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getTextColorForType(riskType),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _getTextColorForType(riskType)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Risk Score
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getIngredientIcon(riskType),
                              color: _getIngredientIconColor(riskType),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Điểm rủi ro: ${(riskScore * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _getTextColorForType(riskType),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Dynamic fields - automatically display all fields from warning
                      ...dynamicFields.entries.map((entry) {
                        return _buildDynamicField(
                          entry.key,
                          entry.value,
                          riskType,
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGradientStartForType(AllergenResultType type) {
    switch (type) {
      case AllergenResultType.allergic:
        return const Color(0xFFFFB3BA);
      case AllergenResultType.safe:
        return const Color(0xFFB3FFD9);
      case AllergenResultType.maybe:
        return const Color(0xFFFFE5B3);
    }
  }

  Color _getGradientEndForType(AllergenResultType type) {
    switch (type) {
      case AllergenResultType.allergic:
        return const Color(0xFFFFD1DC);
      case AllergenResultType.safe:
        return const Color(0xFFD1FFE5);
      case AllergenResultType.maybe:
        return const Color(0xFFFFF4E6);
    }
  }

  Color _getTextColorForType(AllergenResultType type) {
    switch (type) {
      case AllergenResultType.allergic:
        return const Color(0xFF8B1538);
      case AllergenResultType.safe:
        return const Color(0xFF1B5E20);
      case AllergenResultType.maybe:
        return const Color(0xFFE65100);
    }
  }

  Color _getGradientStart() {
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return const Color(0xFFFFB3BA); // Pastel Red
      case AllergenResultType.safe:
        return const Color(0xFFB3FFD9); // Pastel Green
      case AllergenResultType.maybe:
        return const Color(0xFFFFE5B3); // Pastel Yellow
    }
  }

  Color _getGradientEnd() {
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return const Color(0xFFFFD1DC); // Pastel Pink
      case AllergenResultType.safe:
        return const Color(0xFFD1FFE5); // Pastel Mint
      case AllergenResultType.maybe:
        return const Color(0xFFFFF4E6); // Pastel Cream
    }
  }

  IconData _getIcon() {
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return Icons.warning_rounded;
      case AllergenResultType.safe:
        return Icons.check_circle_rounded;
      case AllergenResultType.maybe:
        return Icons.help_outline_rounded;
    }
  }

  String _getMainText() {
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return 'CẢNH BÁO DỊ ỨNG';
      case AllergenResultType.safe:
        return 'AN TOÀN';
      case AllergenResultType.maybe:
        return 'THẬN TRỌNG';
    }
  }

  String _getSubText() {
    // Use overall_recommendation from risk_summary if available
    if (widget.riskSummary != null && widget.riskSummary!['overall_recommendation'] != null) {
      return widget.riskSummary!['overall_recommendation'] as String;
    }
    // Fallback to default text
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return 'Sản phẩm này có thể gây phản ứng dị ứng';
      case AllergenResultType.safe:
        return 'Bạn có thể an toàn sử dụng sản phẩm này';
      case AllergenResultType.maybe:
        return 'Vui lòng kiểm tra kỹ trước khi sử dụng';
    }
  }

  /// Build a dynamic field widget for warning details
  Widget _buildDynamicField(String key, dynamic value, AllergenResultType riskType) {
    // Translate field name to Vietnamese
    final fieldLabel = _translateFieldName(key);

    // Handle different value types
    if (value is List) {
      if (value.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fieldLabel,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getTextColorForType(riskType),
            ),
          ),
          const SizedBox(height: 8),
          ...value.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_right,
                    size: 20,
                    color: _getTextColorForType(riskType),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: TextStyle(
                        fontSize: 15,
                        color: _getTextColorForType(riskType).withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      );
    } else if (value is Map) {
      // Handle nested objects
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fieldLabel,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getTextColorForType(riskType),
            ),
          ),
          const SizedBox(height: 8),
          ...value.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0, left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_translateFieldName(entry.key)}: ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _getTextColorForType(riskType).withOpacity(0.9),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontSize: 15,
                        color: _getTextColorForType(riskType).withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      );
    } else {
      // Handle string, number, boolean
      final stringValue = value.toString();
      if (stringValue.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fieldLabel,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getTextColorForType(riskType),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stringValue,
            style: TextStyle(
              fontSize: 15,
              color: _getTextColorForType(riskType).withOpacity(0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }
  }

  /// Translate field name from English to Vietnamese
  String _translateFieldName(String fieldName) {
    final translations = {
      'summary': 'Tóm tắt',
      'scientific_explanation': 'Giải thích khoa học',
      'potential_effects': 'Tác động tiềm ẩn',
      'recommendation': 'Khuyến nghị',
      'warning_type': 'Loại cảnh báo',
      'severity': 'Mức độ nghiêm trọng',
      'prevention': 'Phòng ngừa',
      'treatment': 'Điều trị',
      'symptoms': 'Triệu chứng',
      'cross_reaction': 'Phản ứng chéo',
      'alternatives': 'Thay thế',
      'notes': 'Ghi chú',
      'source': 'Nguồn',
      'references': 'Tham khảo',
    };

    return translations[fieldName.toLowerCase()] ??
           fieldName.split('_').map((word) =>
             word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
           ).join(' ');
  }

  // Get risk type for a specific ingredient
  // Note: ingredient is already translated to Vietnamese from pantry.dart
  Map<String, dynamic> _getIngredientRiskType(String ingredient) {
    // Check if ingredient has health warning
    // Note: ingredient is already translated, but warning['ingredient'] might be in English/Thai
    if (widget.healthWarnings != null) {
      for (var warning in widget.healthWarnings!) {
        final warningIngredient = warning['ingredient']?.toString() ?? '';

        // Use matching function to check if they match (handles Thai, English, Vietnamese)
        // Since ingredient is already translated, we compare with both original and translated warning
        if (TranslationService.matchesAllergen(ingredient, warningIngredient) ||
            warningIngredient.toLowerCase() == ingredient.toLowerCase() ||
            ingredient.toLowerCase().contains(warningIngredient.toLowerCase()) ||
            warningIngredient.toLowerCase().contains(ingredient.toLowerCase())) {
          final riskScore = (warning['risk_score'] as num?)?.toDouble() ?? 0.0;
          return {
            'type': riskScore >= AllergenThresholds.highRisk ? AllergenResultType.allergic : AllergenResultType.maybe,
            'warning': warning,
            'hasWarning': true,
          };
        }
      }
    }
    // Check if ingredient is in safe list (both are already translated)
    if (widget.safeIngredients != null &&
        widget.safeIngredients!.any((safe) => safe.toLowerCase() == ingredient.toLowerCase())) {
      return {
        'type': AllergenResultType.safe,
        'warning': null,
        'hasWarning': false,
      };
    }
    // Unknown/other ingredient
    return {
      'type': AllergenResultType.maybe,
      'warning': null,
      'hasWarning': false,
    };
  }

  IconData _getIngredientIcon(AllergenResultType riskType) {
    switch (riskType) {
      case AllergenResultType.allergic:
        return Icons.warning_rounded;
      case AllergenResultType.safe:
        return Icons.check_circle_rounded;
      case AllergenResultType.maybe:
        return Icons.help_outline_rounded;
    }
  }

  Color _getIngredientIconColor(AllergenResultType riskType) {
    switch (riskType) {
      case AllergenResultType.allergic:
        return const Color(0xFFD32F2F); // Dark red for contrast
      case AllergenResultType.safe:
        return const Color(0xFF2E7D32); // Dark green for contrast
      case AllergenResultType.maybe:
        return const Color(0xFFF57C00); // Dark orange for contrast
    }
  }

  // Legacy methods for backward compatibility
  IconData _getIngredientIconLegacy() {
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return Icons.close_rounded;
      case AllergenResultType.safe:
        return Icons.check_rounded;
      case AllergenResultType.maybe:
        return Icons.help_outline_rounded;
    }
  }

  Color _getIngredientIconColorLegacy() {
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return const Color(0xFFD32F2F); // Dark red for contrast
      case AllergenResultType.safe:
        return const Color(0xFF2E7D32); // Dark green for contrast
      case AllergenResultType.maybe:
        return const Color(0xFFF57C00); // Dark orange for contrast
    }
  }

  Color _getTextColor() {
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return const Color(0xFF8B1538); // Dark red/pink for contrast
      case AllergenResultType.safe:
        return const Color(0xFF1B5E20); // Dark green for contrast
      case AllergenResultType.maybe:
        return const Color(0xFFE65100); // Dark orange for contrast
    }
  }

  Color _getIconColor() {
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return const Color(0xFFC2185B); // Darker pink for contrast
      case AllergenResultType.safe:
        return const Color(0xFF388E3C); // Darker green for contrast
      case AllergenResultType.maybe:
        return const Color(0xFFF57C00); // Dark orange for contrast
    }
  }

  Widget _buildAnimatedIcon() {
    Widget icon = Icon(
      _getIcon(),
      size: 120,
      color: _getIconColor(),
    );

    if (widget.resultType == AllergenResultType.allergic) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: icon,
          );
        },
      );
    } else if (widget.resultType == AllergenResultType.maybe) {
      return AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _shakeAnimation.value,
            child: icon,
          );
        },
      );
    } else {
      return AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: icon,
          );
        },
      );
    }
  }

  Widget _buildIngredientsList() {
    // Organize ingredients into sections
    final List<String> warningIngredients = [];
    final List<String> safeIngredientList = [];
    final List<String> otherIngredients = [];

    // Use allIngredients if available, otherwise use ingredients
    final allIngredientList = widget.allIngredients ?? widget.ingredients;

    for (var ingredient in allIngredientList) {
      final riskInfo = _getIngredientRiskType(ingredient);
      if (riskInfo['hasWarning'] == true) {
        warningIngredients.add(ingredient);
      } else if (riskInfo['type'] == AllergenResultType.safe) {
        safeIngredientList.add(ingredient);
      } else {
        otherIngredients.add(ingredient);
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getGradientStart().withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thành phần đã phát hiện:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _getTextColor(),
            ),
          ),
          const SizedBox(height: 16),
          // Warning Ingredients Section
          if (warningIngredients.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.warning_rounded, color: Color(0xFFD32F2F), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Cảnh báo dị ứng',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getTextColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...warningIngredients.map((ingredient) {
              final riskInfo = _getIngredientRiskType(ingredient);
              final warning = riskInfo['warning'] as Map<String, dynamic>?;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      _getIngredientIcon(riskInfo['type'] as AllergenResultType),
                      color: _getIngredientIconColor(riskInfo['type'] as AllergenResultType),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ingredient, // Already translated in pantry.dart
                        style: TextStyle(
                          fontSize: 15,
                          color: _getTextColor().withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (warning != null)
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 20),
                        color: _getTextColor(),
                        onPressed: () => _showIngredientDetails(warning),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          // Safe Ingredients Section
          if (safeIngredientList.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Thành phần an toàn',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getTextColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...safeIngredientList.map((ingredient) {
              final riskInfo = _getIngredientRiskType(ingredient);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      _getIngredientIcon(riskInfo['type'] as AllergenResultType),
                      color: _getIngredientIconColor(riskInfo['type'] as AllergenResultType),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ingredient, // Already translated in pantry.dart
                        style: TextStyle(
                          fontSize: 15,
                          color: _getTextColor().withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          // Other Ingredients Section
          if (otherIngredients.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: Color(0xFFF57C00), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Thành phần khác',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getTextColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...otherIngredients.map((ingredient) {
              final riskInfo = _getIngredientRiskType(ingredient);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      _getIngredientIcon(riskInfo['type'] as AllergenResultType),
                      color: _getIngredientIconColor(riskInfo['type'] as AllergenResultType),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ingredient, // Already translated in pantry.dart
                        style: TextStyle(
                          fontSize: 15,
                          color: _getTextColor().withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          // Fallback: if no sections, show all ingredients with legacy icons
          if (warningIngredients.isEmpty && safeIngredientList.isEmpty && otherIngredients.isEmpty) ...[
            ...widget.ingredients.map((ingredient) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      _getIngredientIconLegacy(),
                      color: _getIngredientIconColorLegacy(),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ingredient, // Already translated in pantry.dart
                        style: TextStyle(
                          fontSize: 15,
                          color: _getTextColor().withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_getGradientStart(), _getGradientEnd()],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header với nút đóng
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.close, color: _getTextColor()),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.share, color: _getTextColor()),
                          onPressed: () => _shareResult(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),

                        // Animated Icon
                        _buildAnimatedIcon(),

                        const SizedBox(height: 24),

                        // Main Text
                        Text(
                          _getMainText(),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _getTextColor(),
                            letterSpacing: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        // Sub Text
                        Text(
                          _getSubText(),
                          style: TextStyle(
                            fontSize: 16,
                            color: _getTextColor().withOpacity(0.85),
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        // Ingredients List
                        if (widget.ingredients.isNotEmpty) ...[
                          _buildIngredientsList(),
                        ],

                        const SizedBox(height: 24),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _getTextColor(),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              shadowColor: Colors.black.withOpacity(0.1),
                            ),
                            child: const Text(
                              'Quét lại',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
