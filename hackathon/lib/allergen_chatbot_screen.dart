import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:convert';

import 'allergen_profile_provider.dart';
import 'services/openai_service.dart';
import 'main.dart';

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
  bool _showCompleteButton = false;
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
      'content': '''Bạn là một chatbot thân thiện thu thập hồ sơ sức khỏe. Nhiệm vụ của bạn là thu thập các thông tin sau từ người dùng (TẤT CẢ ĐỀU TÙY CHỌN - người dùng có thể bỏ qua bất kỳ câu hỏi nào):

1. Tên (ví dụ: Thien, Nam, Linh)
2. Tuổi (ví dụ: 24, 30)
3. Cân nặng (ví dụ: 50 kg, 60kg)
4. Loại da (ví dụ: da dầu, da khô, da hỗn hợp, da nhạy cảm)
5. Mục tiêu sức khỏe (ví dụ: giảm cân, tăng cường sức khỏe, chăm sóc da, phòng ngừa dị ứng)
6. Dị ứng thực phẩm (ví dụ: đậu phộng, sữa, trứng, hải sản)
7. Tiền sử bệnh/tình trạng sức khỏe (ví dụ: tiểu đường, cao huyết áp, bệnh tim)

Hỏi từng câu hỏi một cách tự nhiên và thân thiện. Nếu người dùng không muốn trả lời, hãy tôn trọng và chuyển sang câu hỏi tiếp theo.
Hỏi từng câu hỏi một, đợi câu trả lời trước khi hỏi câu tiếp theo.
Nếu người dùng không chắc chắn hoặc không muốn cung cấp thông tin, hãy tôn trọng và chuyển sang câu hỏi khác.
Khi bạn đã hỏi xong tất cả các câu hỏi (hoặc người dùng muốn kết thúc), hãy tóm tắt thông tin đã thu thập được và xác nhận với người dùng bằng cách hỏi "Bạn có muốn lưu thông tin này không?" hoặc tương tự.
Trả lời CHỈ bằng tiếng Việt. Hãy thân thiện và tự nhiên trong giao tiếp.''',
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

      if (_checkIfComplete(response) || userMessage.toLowerCase().contains('done') ||
          userMessage.toLowerCase().contains('save') ||
          userMessage.toLowerCase().contains('yes') ||
          userMessage.toLowerCase().contains('ok')) {
        setState(() {
          _showCompleteButton = true;
        });
      }
      
      final assistantMessages = _messages.where((m) => m['role'] == 'assistant').length;
      if (assistantMessages >= 3 && !_showCompleteButton) {
        setState(() {
          _showCompleteButton = true;
        });
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
    setState(() => _isLoading = true);
    
    try {
      final extractionMessages = List<Map<String, String>>.from(_messages);
      extractionMessages.add({
        'role': 'system',
        'content': '''Dựa trên cuộc trò chuyện ở trên, hãy trích xuất thông tin sau từ câu trả lời của người dùng. Trả về CHỈ một đối tượng JSON với các key chính xác sau (sử dụng chuỗi rỗng "" nếu không được đề cập):
{
  "name": "tên người dùng",
  "age": "tuổi người dùng (chỉ số)",
  "weight": "cân nặng người dùng (chỉ số, có hoặc không có kg)",
  "skin_type": "loại da (ví dụ: da dầu, da khô, da hỗn hợp, da nhạy cảm) - GIỮ NGUYÊN tiếng Việt nếu người dùng nói tiếng Việt",
  "health_goal": "mục tiêu sức khỏe - GIỮ NGUYÊN tiếng Việt nếu người dùng nói tiếng Việt",
  "allergens": "danh sách dị ứng thực phẩm phân cách bằng dấu phẩy - GIỮ NGUYÊN tiếng Việt nếu người dùng nói tiếng Việt",
  "medical_history": "danh sách tiền sử bệnh/tình trạng sức khỏe phân cách bằng dấu phẩy - GIỮ NGUYÊN tiếng Việt nếu người dùng nói tiếng Việt"
}
QUAN TRỌNG: Giữ nguyên ngôn ngữ mà người dùng sử dụng (tiếng Việt). Nếu người dùng nói tiếng Việt, trả về bằng tiếng Việt. Nếu người dùng nói tiếng Anh, dịch sang tiếng Việt.
Trả về CHỈ đối tượng JSON, không có text nào khác.''',
      });
      extractionMessages.add({
        'role': 'user',
        'content': 'Trích xuất tất cả thông tin hồ sơ từ cuộc trò chuyện của chúng ta dưới dạng JSON.',
      });

      final response = await _openAIService.chatCompletion(extractionMessages);
      final responseText = response.trim();
      
      String jsonText = responseText;
      if (jsonText.contains('```')) {
        final start = jsonText.indexOf('{');
        final end = jsonText.lastIndexOf('}');
        if (start != -1 && end != -1) {
          jsonText = jsonText.substring(start, end + 1);
        }
      }
      
      try {
        final extracted = jsonDecode(jsonText) as Map<String, dynamic>;
        
        final name = extracted['name']?.toString().trim() ?? '';
        final age = extracted['age']?.toString().trim() ?? '';
        final weight = extracted['weight']?.toString().trim() ?? '';
        final skinType = extracted['skin_type']?.toString().trim() ?? '';
        final healthGoal = extracted['health_goal']?.toString().trim() ?? '';
        final allergenText = extracted['allergens']?.toString().trim().toLowerCase() ?? '';
        final medicalText = extracted['medical_history']?.toString().trim().toLowerCase() ?? '';
        
        List<String> allergens = [];
        if (allergenText.isNotEmpty && allergenText != 'none') {
          allergens = allergenText
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty && e != 'none')
              .toList();
        }
        
        List<String> medicalHistory = [];
        if (medicalText.isNotEmpty && medicalText != 'none') {
          medicalHistory = medicalText
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty && e != 'none')
              .toList();
        }
        
        setState(() => _isLoading = false);
        await _saveHealthProfile(allergens, medicalHistory, name: name, age: age, weight: weight, skinType: skinType, healthGoal: healthGoal);
      } catch (e) {
        setState(() => _isLoading = false);
        final allergens = _manualExtractAllergens();
        final medicalHistory = _manualExtractMedicalHistory();
        await _saveHealthProfile(allergens, medicalHistory);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      final allergens = _manualExtractAllergens();
      final medicalHistory = _manualExtractMedicalHistory();
      await _saveHealthProfile(allergens, medicalHistory);
    }
  }

  List<String> _manualExtractAllergens() {
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


  Future<void> _saveHealthProfile(
    List<String> allergens,
    List<String> medicalHistory, {
    String name = '',
    String age = '',
    String weight = '',
    String skinType = '',
    String healthGoal = '',
  }) async {
    final provider = Provider.of<AllergenProfileProvider>(context, listen: false);
    final success = await provider.saveProfileInfo(
      allergens: allergens.isNotEmpty ? allergens : null,
      medicalHistory: medicalHistory.isNotEmpty ? medicalHistory : null,
      name: name.isNotEmpty ? name : null,
      age: age.isNotEmpty ? age : null,
      weight: weight.isNotEmpty ? weight : null,
      skinType: skinType.isNotEmpty ? skinType : null,
      healthGoal: healthGoal.isNotEmpty ? healthGoal : null,
    );

    if (mounted) {
      if (success) {
        setState(() => _isComplete = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu hồ sơ sức khỏe thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            if (widget.isEditMode) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
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
                color: const Color(0xFFFFB3C6).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_rounded,
                size: 20,
                color: Color(0xFFFFB3C6),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFFFFB3C6)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isUser ? null : Border.all(
                  color: const Color(0xFFFFB3C6).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                color: Color(0xFFFFB3C6),
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
              Color(0xFFFFF0F5),
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
                                color: const Color(0xFFFFB3C6).withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.psychology_rounded,
                                size: 20,
                                color: Color(0xFFFFB3C6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SpinKitPouringHourGlass(
                              color: Color(0xFFFFB3C6),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showCompleteButton && !_isComplete)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ElevatedButton(
                            onPressed: () {
                              _extractAndSaveHealthProfile();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB3C6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Hoàn Thành',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Nhập câu trả lời của bạn...',
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
                                    color: Color(0xFFFFB3C6),
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
                                  : const Color(0xFFFFB3C6),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: _isLoading || _isComplete ? null : _sendMessage,
                            ),
                          ),
                        ],
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
