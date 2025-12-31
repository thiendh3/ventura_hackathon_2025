import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'search_provider.dart';
import 'allergen_result_screen.dart';
import 'analyzing_screen.dart';
import 'services/device_id_service.dart';
import 'allergen_profile_provider.dart';
import 'services/translation_service.dart';
import 'config/allergen_thresholds.dart';

class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isAnalyzing = false;

  void _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
      // Auto analyze when image is selected
      _analyzeIngredients(image);
    }
  }

  Future<void> _analyzeIngredients(XFile image) async {
    // Show analyzing screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AnalyzingScreen(),
        fullscreenDialog: true,
      ),
    );

    // Wait a bit for animation, then analyze
    await Future.delayed(const Duration(milliseconds: 500));
    await detectIngredientByImage(image);
  }

  AllergenResultType _getResultType() {
    return AllergenResultType.safe;
  }

  AllergenResultType _calculateResultType(List<dynamic>? healthWarnings, Map<String, dynamic>? riskSummary) {
    if (healthWarnings != null && healthWarnings.isNotEmpty) {
      double maxWarningScore = 0.0;
      for (var warning in healthWarnings) {
        final riskScore = (warning['risk_score'] as num?)?.toDouble() ?? 0.0;
        if (riskScore > maxWarningScore) {
          maxWarningScore = riskScore;
        }
      }

      if (maxWarningScore >= AllergenThresholds.highRisk) {
        return AllergenResultType.allergic;
      } else if (maxWarningScore >= AllergenThresholds.mediumRisk) {
        return AllergenResultType.maybe;
      } else if (maxWarningScore > AllergenThresholds.lowRisk) {
        return AllergenResultType.maybe;
      }
    }

    if (riskSummary != null && riskSummary['max_risk_score'] != null) {
      final maxRiskScore = (riskSummary['max_risk_score'] as num).toDouble();

      if (maxRiskScore >= AllergenThresholds.highRisk) {
        return AllergenResultType.allergic;
      } else if (maxRiskScore >= AllergenThresholds.mediumRisk) {
        return AllergenResultType.maybe;
      } else {
        return AllergenResultType.safe;
      }
    }

    return _getResultType();
  }

  Future<void> detectIngredientByImage(XFile image) async {
    const String apiUrl = 'https://asia-southeast1-hackathon-2026-482104.cloudfunctions.net/smart_ocr_rag';
    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        image.path,
        filename: image.name,
      ),
    );

    try {
      final deviceId = await DeviceIdService().getDeviceId();
      request.fields['device_id'] = deviceId;
    } catch (e) {
      // Device ID error, continue with request
    }

    try {
      final allergenProvider = Provider.of<AllergenProfileProvider>(context, listen: false);
      final healthProfile = {
        'allergy': allergenProvider.allergens,
        'medical_history': allergenProvider.medicalHistory,
      };
      final healthProfileJson = jsonEncode(healthProfile);
      request.fields['health_profile'] = healthProfileJson;
    } catch (e) {
    }

    try {
      var response = await request.send();
      var responseBody = await http.Response.fromStream(response);
      var decodedBody = utf8.decode(responseBody.bodyBytes);
      var jsonResponse = jsonDecode(decodedBody);

      if (response.statusCode == 200) {
        if (jsonResponse['success'] == true && jsonResponse['ingredients'] != null) {
          var ingredients = jsonResponse['ingredients'] as List;
          List<String> ingredientsList = ingredients.map((e) => e.toString()).toList();
          ingredientsList = await TranslationService().translateIngredients(ingredientsList);

          final healthWarnings = jsonResponse['health_warnings'] as List<dynamic>?;
          final riskSummary = jsonResponse['risk_summary'] as Map<String, dynamic>?;
          final safeIngredients = (jsonResponse['safe_ingredients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [];
          final safeIngredientsTranslated = await TranslationService().translateIngredients(safeIngredients);

          final allergenProvider = Provider.of<AllergenProfileProvider>(context, listen: false);
          final userAllergens = allergenProvider.allergens;

          bool hasHiddenAllergen = false;
          for (var ingredient in ingredientsList) {
            for (var allergen in userAllergens) {
              final translatedAllergen = await TranslationService().translateIngredient(allergen);
              if (TranslationService.matchesAllergen(ingredient, translatedAllergen) ||
                  TranslationService.matchesAllergen(ingredient, allergen)) {
                hasHiddenAllergen = true;
                break;
              }
            }
            if (hasHiddenAllergen) break;
          }

          AllergenResultType resultType = _calculateResultType(healthWarnings, riskSummary);

          if (mounted) {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AllergenResultScreen(
                  resultType: resultType,
                  ingredients: ingredientsList,
                  imagePath: image.path,
                  healthWarnings: healthWarnings?.cast<Map<String, dynamic>>(),
                  riskSummary: riskSummary,
                  safeIngredients: safeIngredientsTranslated,
                  allIngredients: ingredientsList,
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(jsonResponse['error'] ?? 'Không tìm thấy thành phần trong hình ảnh')),
            );
          }
        }
      } else {
        var errorMsg = jsonResponse['error'] ?? 'Lỗi với mã trạng thái: ${response.statusCode}';
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $errorMsg')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xử lý hình ảnh: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: const Text(
          'Máy ảnh',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFF0F5),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Section
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFB3C6).withOpacity(0.3),
                      const Color(0xFFFFB3C6).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB3C6).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Color(0xFFFFB3C6),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chụp ảnh sản phẩm',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Phân tích thành phần thông minh',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF5A6C7D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Image Upload Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                    Row(
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          color: Color(0xFFFFB3C6),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Hình ảnh sản phẩm',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFE9ECEF),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFFF8F9FA),
                      ),
                      child: _selectedImages.isEmpty
                          ? GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.photo_library),
                                            title: const Text('Tải lên từ thư viện'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickImage(ImageSource.gallery);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.camera_alt),
                                            title: const Text('Chụp ảnh'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickImage(ImageSource.camera);
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFDEE2E6),
                                    width: 2,
                                    style: BorderStyle.solid,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFB3C6).withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 48,
                                        color: Color(0xFFFFB3C6),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Nhấn để thêm ảnh',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                ..._selectedImages.map((image) {
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            File(image.path),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedImages.remove(image);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
