import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AllergenResultType {
  allergic, // Allergic
  safe,     // Safe
  maybe,    // Maybe
}

class AllergenResultScreen extends StatefulWidget {
  final AllergenResultType resultType;
  final List<String> ingredients;
  final String? imagePath;

  const AllergenResultScreen({
    super.key,
    required this.resultType,
    required this.ingredients,
    this.imagePath,
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
        content: Text('Result copied to clipboard! You can share it anywhere.'),
        duration: Duration(seconds: 2),
      ),
    );
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
        return 'ALLERGY WARNING';
      case AllergenResultType.safe:
        return 'SAFE TO USE';
      case AllergenResultType.maybe:
        return 'CAUTION';
    }
  }

  String _getSubText() {
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return 'This product may cause allergic reactions';
      case AllergenResultType.safe:
        return 'You can safely use this product';
      case AllergenResultType.maybe:
        return 'Please check carefully before using';
    }
  }

  IconData _getIngredientIcon() {
    switch (widget.resultType) {
      case AllergenResultType.allergic:
        return Icons.close_rounded;
      case AllergenResultType.safe:
        return Icons.check_rounded;
      case AllergenResultType.maybe:
        return Icons.help_outline_rounded;
    }
  }

  Color _getIngredientIconColor() {
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
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: _getTextColor()),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      IconButton(
                        icon: Icon(Icons.share, color: _getTextColor()),
                        onPressed: () => _shareResult(),
                      ),
                    ],
                  ),
                ),

                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        // Animated Icon
                        _buildAnimatedIcon(),

                        const SizedBox(height: 32),

                        // Main Text
                        Text(
                          _getMainText(),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: _getTextColor(),
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Sub Text
                        Text(
                          _getSubText(),
                          style: TextStyle(
                            fontSize: 18,
                            color: _getTextColor().withOpacity(0.85),
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 48),

                        // Ingredients List
                        if (widget.ingredients.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getGradientStart().withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Detected Ingredients:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _getTextColor(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...widget.ingredients.map((ingredient) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getIngredientIcon(),
                                          color: _getIngredientIconColor(),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            ingredient,
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
                            ),
                          ),
                        ],

                        const SizedBox(height: 48),

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
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Scan Again',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
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
