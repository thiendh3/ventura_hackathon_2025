import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AllergenProfileProvider with ChangeNotifier {
  static const String _profileKey = 'user_allergen_profile';
  List<String> _allergens = [];
  List<String> _medicalHistory = [];
  String _name = '';
  String _age = '';
  String _weight = '';
  String _skinType = '';
  String _healthGoal = '';
  bool _isLoading = false;

  List<String> get allergens => _allergens;
  List<String> get medicalHistory => _medicalHistory;
  String get name => _name;
  String get age => _age;
  String get weight => _weight;
  String get skinType => _skinType;
  String get healthGoal => _healthGoal;
  bool get isLoading => _isLoading;
  bool get hasProfile => _allergens.isNotEmpty || _medicalHistory.isNotEmpty || _name.isNotEmpty;

  AllergenProfileProvider() {
    loadProfile();
  }

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_profileKey);

      if (profileJson != null && profileJson.isNotEmpty) {
        final decoded = jsonDecode(profileJson);
        
        if (decoded is List) {
          _allergens = decoded.map((e) => e.toString()).toList();
          _medicalHistory = [];
          await _saveToPreferences();
        } else if (decoded is Map) {
          _allergens = (decoded['allergy'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _medicalHistory = (decoded['medical_history'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _name = decoded['name']?.toString() ?? '';
          _age = decoded['age']?.toString() ?? '';
          _weight = decoded['weight']?.toString() ?? '';
          _skinType = decoded['skin_type']?.toString() ?? '';
          _healthGoal = decoded['health_goal']?.toString() ?? '';
        } else {
          _allergens = [];
          _medicalHistory = [];
          _name = '';
          _age = '';
          _weight = '';
          _skinType = '';
          _healthGoal = '';
        }
      } else {
        _allergens = [];
        _medicalHistory = [];
        _name = '';
        _age = '';
        _weight = '';
        _skinType = '';
        _healthGoal = '';
      }
    } catch (e) {
      _allergens = [];
      _medicalHistory = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileData = {
        'allergy': _allergens,
        'medical_history': _medicalHistory,
        'name': _name,
        'age': _age,
        'weight': _weight,
        'skin_type': _skinType,
        'health_goal': _healthGoal,
      };
      final profileJson = jsonEncode(profileData);
      await prefs.setString(_profileKey, profileJson);
    } catch (e) {
    }
  }

  Future<bool> saveProfile(List<String> allergens, List<String> medicalHistory) async {
    try {
      _allergens = allergens;
      _medicalHistory = medicalHistory;
      await _saveToPreferences();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> saveProfileInfo({
    String? name,
    String? age,
    String? weight,
    String? skinType,
    String? healthGoal,
    List<String>? allergens,
    List<String>? medicalHistory,
  }) async {
    try {
      if (name != null) _name = name;
      if (age != null) _age = age;
      if (weight != null) _weight = weight;
      if (skinType != null) _skinType = skinType;
      if (healthGoal != null) _healthGoal = healthGoal;
      if (allergens != null) _allergens = allergens;
      if (medicalHistory != null) _medicalHistory = medicalHistory;
      await _saveToPreferences();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateAllergens(List<String> newAllergens) async {
    _allergens = newAllergens;
    await _saveToPreferences();
    notifyListeners();
  }

  Future<void> updateMedicalHistory(List<String> newMedicalHistory) async {
    _medicalHistory = newMedicalHistory;
    await _saveToPreferences();
    notifyListeners();
  }

  Future<void> clearProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileKey);
      _allergens = [];
      _medicalHistory = [];
      _name = '';
      _age = '';
      _weight = '';
      _skinType = '';
      _healthGoal = '';
      notifyListeners();
    } catch (e) {
    }
  }

  Future<bool> checkHasProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_profileKey);
      if (profileJson == null || profileJson.isEmpty) {
        return false;
      }
      final decoded = jsonDecode(profileJson);
      if (decoded is List) {
        return decoded.isNotEmpty;
      } else if (decoded is Map) {
        final allergies = decoded['allergy'] as List?;
        final medicalHistory = decoded['medical_history'] as List?;
        return (allergies?.isNotEmpty ?? false) || (medicalHistory?.isNotEmpty ?? false);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
