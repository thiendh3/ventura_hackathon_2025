import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';

// import 'auth_provider.dart';
// import 'login_page.dart';
import 'search_provider.dart';
import 'allergen_result_screen.dart';
import 'analyzing_screen.dart';
// import 'user_page.dart';

class Pantry extends StatefulWidget {
  const Pantry({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PantryState createState() => _PantryState();
}

class _PantryState extends State<Pantry> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // late stt.SpeechToText _speech;
  // bool _isListening = false;
  // String _spokenText = '';
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isAnalyzing = false;
  int _scanCount = 0; // Count scans to rotate results

  void _pickImage(BuildContext context, ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  Future<void> _analyzeIngredients() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    // Show analyzing screen
    if (_selectedImages.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const AnalyzingScreen(),
          fullscreenDialog: true,
        ),
      );

      // Wait a bit for animation, then analyze
      await Future.delayed(const Duration(milliseconds: 500));
      await detectIngredientByImage(_selectedImages[0]);
    }
  }

  AllergenResultType _getResultType() {
    switch (_scanCount % 3) {
      case 0:
        return AllergenResultType.allergic;
      case 1:
        return AllergenResultType.safe;
      case 2:
        return AllergenResultType.maybe;
      default:
        return AllergenResultType.allergic;
    }
  }

  // void _startListening() async {
  //   bool available = await _speech.initialize();
  //   if (available) {
  //     setState(() => _isListening = true);
  //     _speech.listen(onResult: (result) {
  //       setState(() {
  //         _spokenText = result.recognizedWords;
  //       });
  //     });
  //   } else {
  //     setState(() => _isListening = false);
  //   }
  // }

  // void _stopListening() {
  //   setState(() => _isListening = false);
  //   _speech.stop();
  //   if (_spokenText.isNotEmpty) {
  //     List<String> ingredients = _spokenText.split(',').map((s) => s.trim()).toList();
  //     Provider.of<SearchProvider>(context, listen: false).addMultipleSearchValues(ingredients);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Ingredients added: $_spokenText')),
  //     );
  //     _spokenText = '';
  //   }
  // }

  // Debug dialog - có thể uncomment để test
  // void _showOutputDialog(Map<String, dynamic> jsonResponse, int statusCode) {
  //   if (!mounted) return;

  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Row(
  //           children: [
  //             Icon(
  //               statusCode == 200 ? Icons.check_circle : Icons.error,
  //               color: statusCode == 200 ? Colors.green : Colors.red,
  //             ),
  //             const SizedBox(width: 8),
  //             Text('API Response (${statusCode})'),
  //           ],
  //         ),
  //         content: SingleChildScrollView(
  //           child: Container(
  //             width: double.maxFinite,
  //             padding: const EdgeInsets.all(12),
  //             decoration: BoxDecoration(
  //               color: Colors.grey.shade100,
  //               borderRadius: BorderRadius.circular(8),
  //               border: Border.all(color: Colors.grey.shade300),
  //             ),
  //             child: SelectableText(
  //               const JsonEncoder.withIndent('  ').convert(jsonResponse),
  //               style: const TextStyle(
  //                 fontFamily: 'monospace',
  //                 fontSize: 12,
  //               ),
  //             ),
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: const Text('Đóng'),
  //           ),
  //           if (jsonResponse['ingredients'] != null)
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.of(context).pop();
  //                 // Copy ingredients to clipboard hoặc hiển thị thêm
  //               },
  //               child: const Text('OK'),
  //             ),
  //         ],
  //       );
  //     },
  //   );
  // }

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
      var response = await request.send();
      var responseBody = await http.Response.fromStream(response);
      var decodedBody = utf8.decode(responseBody.bodyBytes);
      var jsonResponse = jsonDecode(decodedBody);

      // Hiển thị dialog để kiểm tra output (có thể comment lại sau khi test xong)
      // _showOutputDialog(jsonResponse, response.statusCode);

      if (response.statusCode == 200) {
        if (jsonResponse['success'] == true && jsonResponse['ingredients'] != null) {
          var ingredients = jsonResponse['ingredients'] as List;
          List<String> ingredientsList = ingredients.map((e) => e.toString()).toList();

          // Lưu vào SearchProvider
          setState(() => Provider.of<SearchProvider>(context, listen: false).addSearchValues(ingredientsList));

          // Tính result type dựa trên scan count
          AllergenResultType resultType = _getResultType();

          // Tăng scan count cho lần scan tiếp theo
          setState(() {
            _scanCount++;
          });

          // Navigate to result screen (pop analyzing screen first)
          if (mounted) {
            Navigator.of(context).pop(); // Close analyzing screen
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AllergenResultScreen(
                  resultType: resultType,
                  ingredients: ingredientsList,
                  imagePath: image.path,
                ),
              ),
            );
          }
        } else {
          print('API returned success=false or missing ingredients');
          if (mounted) {
            Navigator.of(context).pop(); // Close analyzing screen
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(jsonResponse['error'] ?? 'No ingredients found in image')),
            );
          }
        }
      } else {
        var errorMsg = jsonResponse['error'] ?? 'Failed with status code: ${response.statusCode}';
        print('Failed with status code: ${response.statusCode}, error: $errorMsg');
        if (mounted) {
          Navigator.of(context).pop(); // Close analyzing screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $errorMsg')),
          );
        }
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close analyzing screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // _speech = stt.SpeechToText();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo SVG
            SvgPicture.string(
              '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" fill="#FFB3C6" stroke="#000000" stroke-width="2"></path><path d="M14.5 9.1c-.3-1.4-1.5-2.6-3-2.6-1.7 0-3.1 1.4-3.1 3.1 0 1.5.9 2.8 2.2 3.1" fill="none" stroke="#000000" stroke-width="2"></path><path d="M9.5 14.9c.3 1.4 1.5 2.6 3 2.6 1.7 0 3.1-1.4 3.1-3.1 0-1.5-.9-2.8-2.2-3.1" fill="none" stroke="#000000" stroke-width="2"></path></svg>''',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 8),
            // Text "Safein"
            const Text(
              'Safein',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
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
              const Color(0xFFF8F9FA),
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
                      const Color(0xFFB3FFD9),
                      const Color(0xFFD1FFE5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB3FFD9).withOpacity(0.3),
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
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.psychology_rounded,
                            color: Color(0xFF4ECDC4),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Allergen Scanner',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Smart ingredient analysis',
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
                    const SizedBox(height: 24),
                    Text(
                      'Upload a photo of the product\'s ingredients label to check for allergens.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
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
                        Icon(
                          Icons.image_outlined,
                          color: const Color(0xFF4ECDC4),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Product Image',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Image Display Area
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
                                                title: const Text('Upload from Gallery'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _pickImage(context, ImageSource.gallery);
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.camera_alt),
                                                title: const Text('Take a Picture'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _pickImage(context, ImageSource.camera);
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
                                            color: const Color(0xFFB3FFD9).withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 48,
                                            color: Color(0xFF4ECDC4),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Tap to add photo',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
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
                                    GestureDetector(
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
                                                    title: const Text('Upload from Gallery'),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      _pickImage(context, ImageSource.gallery);
                                                    },
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(Icons.camera_alt),
                                                    title: const Text('Take a Picture'),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      _pickImage(context, ImageSource.camera);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 2,
                                            style: BorderStyle.solid,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add,
                                              size: 32,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Add more',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Analyze Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAnalyzing ? null : _analyzeIngredients,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFF4ECDC4).withOpacity(0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Analyze with AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
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
}
