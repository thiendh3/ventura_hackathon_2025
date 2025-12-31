import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'allergen_profile_provider.dart';
import 'services/translation_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final TextEditingController _newProfileController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _skinTypeController = TextEditingController();
  final TextEditingController _healthGoalController = TextEditingController();
  final TextEditingController _allergensController = TextEditingController();
  final TextEditingController _medicalHistoryController = TextEditingController();
  bool _isEditing = false;
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    _loadProfileData().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadProfileData() async {
    final provider = Provider.of<AllergenProfileProvider>(context, listen: false);
    _nameController.text = provider.name;
    _ageController.text = provider.age;
    _weightController.text = provider.weight;
    
    _skinTypeController.text = await _translationService.translateText(provider.skinType);
    _healthGoalController.text = await _translationService.translateText(provider.healthGoal);
    
    final translatedAllergens = await _translationService.translateList(provider.allergens);
    _allergensController.text = translatedAllergens.join(', ');
    
    final translatedMedicalHistory = await _translationService.translateList(provider.medicalHistory);
    _medicalHistoryController.text = translatedMedicalHistory.join(', ');
  }

  Future<void> _saveProfile() async {
    final provider = Provider.of<AllergenProfileProvider>(context, listen: false);
    
    final allergens = _allergensController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    
    final medicalHistory = _medicalHistoryController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    
    final success = await provider.saveProfileInfo(
      name: _nameController.text.trim(),
      age: _ageController.text.trim(),
      weight: _weightController.text.trim(),
      skinType: _skinTypeController.text.trim(),
      healthGoal: _healthGoalController.text.trim(),
      allergens: allergens,
      medicalHistory: medicalHistory,
    );
    
    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu thông tin thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _newProfileController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _skinTypeController.dispose();
    _healthGoalController.dispose();
    _allergensController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AllergenProfileProvider>(context);
    final profileName = provider.name.isNotEmpty ? provider.name : 'thien';
    final profileAge = provider.age.isNotEmpty ? provider.age : '24';
    final profileWeight = provider.weight.isNotEmpty ? provider.weight : '50';
    
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildYourProfilesSection(profileName, profileAge, profileWeight),
              const SizedBox(height: 24),
              _buildEditingSection(profileName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              const Text(
                'SAFE',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFB3C6),
                ),
              ),
              const Text(
                'IN',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4ECDC4),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFFFFB3C6),
                size: 24,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYourProfilesSection(String profileName, String profileAge, String profileWeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hồ sơ của bạn',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.red,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB3C6).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFFFFB3C6),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profileName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFB3C6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profileAge} Y/O, ${profileWeight} KG',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _newProfileController,
                  decoration: const InputDecoration(
                    hintText: 'Tên hồ sơ mới...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                if (_newProfileController.text.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã đạt giới hạn hồ sơ (gói cơ bản)'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  _newProfileController.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
                  child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 4),
                  Text('THÊM'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Giới hạn hồ sơ: 1/1 (gói cơ bản)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEditingSection(String profileName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                children: [
                  const TextSpan(text: 'Chỉnh sửa: '),
                  TextSpan(
                    text: profileName,
                    style: const TextStyle(color: Color(0xFFFFB3C6)),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (_isEditing)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _loadProfileData();
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'HỦY',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    if (_isEditing) {
                      _saveProfile();
                    } else {
                      setState(() {
                        _isEditing = true;
                      });
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                    child: Text(
                    _isEditing ? 'LƯU' : 'CHỈNH SỬA',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THÔNG TIN CƠ BẢN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFB3C6),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _nameController,
                  enabled: _isEditing,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _ageController,
                        enabled: _isEditing,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _weightController,
                        enabled: _isEditing,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LOẠI DA',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFB3C6),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _skinTypeController,
                  enabled: _isEditing,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _skinTypeController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    color: _skinTypeController.text.isEmpty ? Colors.grey.shade600 : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Chưa xác định',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MỤC TIÊU SỨC KHỎE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFB3C6),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _healthGoalController,
                  enabled: _isEditing,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _healthGoalController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    color: _healthGoalController.text.isEmpty ? Colors.grey.shade600 : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Chưa xác định',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DỊ ỨNG',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFB3C6),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _allergensController,
                  enabled: _isEditing,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _allergensController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    color: _allergensController.text.isEmpty ? Colors.grey.shade600 : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: đậu phộng, sữa, trứng (phân cách bằng dấu phẩy)',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TIỀN SỬ BỆNH',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFB3C6),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _medicalHistoryController,
                  enabled: _isEditing,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _medicalHistoryController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    color: _medicalHistoryController.text.isEmpty ? Colors.grey.shade600 : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: tiểu đường, cao huyết áp (phân cách bằng dấu phẩy)',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
