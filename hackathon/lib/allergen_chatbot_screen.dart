import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';

import 'allergen_profile_provider.dart';
import 'services/openai_service.dart';
import 'pantry.dart';

class AllergenChatbotScreen extends StatefulWidget {
  final bool isEditMode;

  const AllergenChatbotScreen({super.key, this.isEditMode = false});

  @override
  State<AllergenChatbotScreen> createState() => _AllergenChatbotScreenState();
}

class _AllergenChatbotScreenState extends State<AllergenChatbotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OpenAIService _openAIService = OpenAIService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isComplete = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeChat() {
    final systemPrompt = {
      'role': 'system',
      'content': '''Bạn là một chatbot thu thập hồ sơ sức khỏe. Nhiệm vụ của bạn là thu thập hai loại thông tin từ người dùng:
1. Dị ứng thực phẩm (ví dụ: đậu phộng, sữa, trứng, hải sản)
2. Tiền sử bệnh/tình trạng sức khỏe (ví dụ: tiểu đường, cao huyết áp, bệnh tim)

Hỏi về dị ứng thực phẩm TRƯỚC. Sau khi thu thập thông tin dị ứng, mới hỏi về tiền sử bệnh.
Hỏi từng câu hỏi một, đợi câu trả lời trước khi hỏi câu tiếp theo.
Nếu người dùng không chắc chắn, hãy hỏi thêm các câu hỏi hướng dẫn để giúp họ xác định thông tin.
Khi bạn đã thu thập đủ thông tin về CẢ dị ứng và tiền sử bệnh, hãy tóm tắt cả hai danh sách và xác nhận với người dùng bằng cách hỏi "Bạn có muốn lưu thông tin này không?" hoặc tương tự.
Trả lời CHỈ bằng tiếng Việt.''',
    };

    _messages.add(systemPrompt);
    _sendInitialMessage();
  }

  Future<void> _sendInitialMessage() async {
    setState(() => _isLoading = true);

    try {
      final response = await _openAIService.chatCompletion(_messages);
      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final userMessage = _messageController.text.trim();
    if (userMessage.isEmpty || _isLoading || _isComplete) return;

    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _openAIService.chatCompletion(_messages);
      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _isLoading = false;
      });

      // Check if conversation is complete
      if (_checkIfComplete(response) || userMessage.toLowerCase().contains('done') ||
          userMessage.toLowerCase().contains('save') ||
          userMessage.toLowerCase().contains('yes') ||
          userMessage.toLowerCase().contains('ok')) {
        _extractAndSaveHealthProfile();
      }

      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _checkIfComplete(String response) {
    final lowerResponse = response.toLowerCase();
    return lowerResponse.contains('summary') ||
        lowerResponse.contains('confirm') ||
        lowerResponse.contains('save') ||
        lowerResponse.contains('complete') ||
        lowerResponse.contains('finished');
  }

  Future<void> _extractAndSaveHealthProfile() async {
    // Use AI to extract both allergens and medical history from conversation
    setState(() => _isLoading = true);
    
    try {
      // Extract allergens
      final allergenExtractionMessages = List<Map<String, String>>.from(_messages);
      allergenExtractionMessages.add({
        'role': 'system',
        'content': '''Based on the conversation above, extract a list of food allergens mentioned by the user.
Return ONLY a comma-separated list of allergens in English (e.g., "peanuts, milk, eggs").
If no allergens were mentioned, return "none".
Do not include any other text, just the list or "none".''',
      });
      allergenExtractionMessages.add({
        'role': 'user',
        'content': 'Extract the list of allergens from our conversation.',
      });

      final allergenResponse = await _openAIService.chatCompletion(allergenExtractionMessages);
      final allergenText = allergenResponse.trim().toLowerCase();
      
      List<String> allergens = [];
      if (allergenText != 'none' && allergenText.isNotEmpty) {
        allergens = allergenText
            .replaceAll(RegExp(r'[^\w\s,]+'), '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && e != 'none')
            .toList();
      }

      // Extract medical history
      final medicalExtractionMessages = List<Map<String, String>>.from(_messages);
      medicalExtractionMessages.add({
        'role': 'system',
        'content': '''Based on the conversation above, extract a list of medical conditions or health issues mentioned by the user (e.g., diabetes, hypertension, heart disease).
Return ONLY a comma-separated list of medical conditions in English.
If no medical conditions were mentioned, return "none".
Do not include any other text, just the list or "none".''',
      });
      medicalExtractionMessages.add({
        'role': 'user',
        'content': 'Extract the list of medical conditions from our conversation.',
      });

      final medicalResponse = await _openAIService.chatCompletion(medicalExtractionMessages);
      final medicalText = medicalResponse.trim().toLowerCase();
      
      List<String> medicalHistory = [];
      if (medicalText != 'none' && medicalText.isNotEmpty) {
        medicalHistory = medicalText
            .replaceAll(RegExp(r'[^\w\s,]+'), '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && e != 'none')
            .toList();
      }

      setState(() => _isLoading = false);

      // If nothing extracted, show dialog
      if (allergens.isEmpty && medicalHistory.isEmpty) {
        _showHealthProfileInputDialog();
      } else {
        await _saveHealthProfile(allergens, medicalHistory);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // If AI extraction fails, try manual extraction as fallback
      final allergens = _manualExtractAllergens();
      final medicalHistory = _manualExtractMedicalHistory();
      if (allergens.isEmpty && medicalHistory.isEmpty) {
        _showHealthProfileInputDialog();
      } else {
        await _saveHealthProfile(allergens, medicalHistory);
      }
    }
  }

  List<String> _manualExtractAllergens() {
    // Fallback manual extraction
    final allergens = <String>[];
    final allergenKeywords = {
      'peanut': ['peanut', 'peanuts', 'groundnut'],
      'milk': ['milk', 'dairy', 'lactose', 'cheese', 'butter'],
      'egg': ['egg', 'eggs'],
      'fish': ['fish', 'salmon', 'tuna', 'cod'],
      'shellfish': ['shrimp', 'crab', 'lobster', 'shellfish', 'prawn'],
      'soy': ['soy', 'soya', 'soybean'],
      'wheat': ['wheat', 'gluten', 'flour'],
      'sesame': ['sesame', 'tahini'],
      'tree nut': ['almond', 'walnut', 'cashew', 'pistachio', 'hazelnut', 'tree nut'],
    };

    for (var msg in _messages) {
      if (msg['role'] == 'user' || msg['role'] == 'assistant') {
        final content = msg['content']?.toLowerCase() ?? '';
        allergenKeywords.forEach((allergen, keywords) {
          for (var keyword in keywords) {
            if (content.contains(keyword) && !allergens.contains(allergen)) {
              allergens.add(allergen);
              break;
            }
          }
        });
      }
    }

    return allergens;
  }

  List<String> _manualExtractMedicalHistory() {
    // Fallback manual extraction for medical history
    final medicalHistory = <String>[];
    final medicalKeywords = {
      'diabetes': ['diabetes', 'diabetic', 'blood sugar', 'glucose'],
      'hypertension': ['hypertension', 'high blood pressure', 'blood pressure'],
      'heart disease': ['heart disease', 'cardiac', 'heart condition', 'cardiovascular'],
      'asthma': ['asthma', 'asthmatic'],
      'kidney disease': ['kidney', 'renal'],
      'liver disease': ['liver', 'hepatic'],
    };

    for (var msg in _messages) {
      if (msg['role'] == 'user' || msg['role'] == 'assistant') {
        final content = msg['content']?.toLowerCase() ?? '';
        medicalKeywords.forEach((condition, keywords) {
          for (var keyword in keywords) {
            if (content.contains(keyword) && !medicalHistory.contains(condition)) {
              medicalHistory.add(condition);
              break;
            }
          }
        });
      }
    }

    return medicalHistory;
  }

  void _showHealthProfileInputDialog() {
    final allergenController = TextEditingController();
    final medicalHistoryController = TextEditingController();
    showDialog(
      barrierDismissible: false,
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFB3FFD9),
                Color(0xFFD1FFE5),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        Icons.health_and_safety_rounded,
                        color: Color(0xFF4ECDC4),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Nhập hồ sơ sức khỏe',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Allergens field
                const Text(
                  'Dị ứng thực phẩm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: allergenController,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: đậu phộng, sữa, trứng (phân cách bằng dấu phẩy)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 16),
                // Medical History field
                const Text(
                  'Tiền sử bệnh',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: medicalHistoryController,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: tiểu đường, cao huyết áp (phân cách bằng dấu phẩy)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hồ sơ sức khỏe chưa được lưu. Bạn có thể thiết lập sau từ hồ sơ của mình.'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          color: Color(0xFF5A6C7D),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final allergens = allergenController.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        final medicalHistory = medicalHistoryController.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        
                        if (allergens.isNotEmpty || medicalHistory.isNotEmpty) {
                          Navigator.pop(context);
                          _saveHealthProfile(allergens, medicalHistory);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vui lòng nhập ít nhất một mục trong dị ứng hoặc tiền sử bệnh'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Lưu',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveHealthProfile(List<String> allergens, List<String> medicalHistory) async {
    final provider = Provider.of<AllergenProfileProvider>(context, listen: false);
    final success = await provider.saveProfile(allergens, medicalHistory);

    if (mounted) {
      if (success) {
        setState(() => _isComplete = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu hồ sơ sức khỏe thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate based on mode
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            if (widget.isEditMode) {
              // If in edit mode, go back to previous screen
              Navigator.of(context).pop();
            } else {
              // First time setup, go to pantry
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const Pantry()),
              );
            }
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi lưu thông tin'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(Map<String, String> message, bool isUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFB3FFD9).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_rounded,
                size: 20,
                color: Color(0xFF4ECDC4),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF4ECDC4)
                    : const Color(0xFFB3FFD9).withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message['content'] ?? '',
                style: TextStyle(
                  fontSize: 15,
                  color: isUser ? Colors.white : const Color(0xFF2C3E50),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF4ECDC4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 20,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(
              '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" fill="#FFB3C6" stroke="#000000" stroke-width="2"></path><path d="M14.5 9.1c-.3-1.4-1.5-2.6-3-2.6-1.7 0-3.1 1.4-3.1 3.1 0 1.5.9 2.8 2.2 3.1" fill="none" stroke="#000000" stroke-width="2"></path><path d="M9.5 14.9c.3 1.4 1.5 2.6 3 2.6 1.7 0 3.1-1.4 3.1-3.1 0-1.5-.9-2.8-2.2-3.1" fill="none" stroke="#000000" stroke-width="2"></path></svg>''',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 8),
            const Text(
              'Thiết lập hồ sơ dị ứng',
              style: TextStyle(
                fontSize: 20,
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F9FA),
              Colors.white,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _messages.length) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'user';
                      if (message['role'] == 'system') {
                        return const SizedBox.shrink();
                      }
                      return _buildMessageBubble(message, isUser);
                    } else {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFB3FFD9).withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.psychology_rounded,
                                size: 20,
                                color: Color(0xFF4ECDC4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SpinKitPouringHourGlass(
                              color: Color(0xFF4ECDC4),
                              size: 30,
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type your answer...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF4ECDC4),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          enabled: !_isLoading && !_isComplete,
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _isLoading || _isComplete
                              ? Colors.grey
                              : const Color(0xFF4ECDC4),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _isLoading || _isComplete ? null : _sendMessage,
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
