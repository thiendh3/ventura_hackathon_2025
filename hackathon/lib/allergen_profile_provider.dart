import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AllergenProfileProvider with ChangeNotifier {
  static const String _profileKey = 'user_allergen_profile';
  List<String> _allergens = [];
  List<String> _medicalHistory = [];
  bool _isLoading = false;

  List<String> get allergens => _allergens;
  List<String> get medicalHistory => _medicalHistory;
  bool get isLoading => _isLoading;
  bool get hasProfile => _allergens.isNotEmpty || _medicalHistory.isNotEmpty;

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
        
        // Handle migration from old format (just a list) to new format (object)
        if (decoded is List) {
          // Old format: just a list of allergens
          _allergens = decoded.map((e) => e.toString()).toList();
          _medicalHistory = [];
          // Save in new format for future
          await _saveToPreferences();
        } else if (decoded is Map) {
          // New format: object with allergy and medical_history
          _allergens = (decoded['allergy'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _medicalHistory = (decoded['medical_history'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
        } else {
          _allergens = [];
          _medicalHistory = [];
        }
      } else {
        _allergens = [];
        _medicalHistory = [];
      }
    } catch (e) {
      print('Error loading allergen profile: $e');
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
      };
      final profileJson = jsonEncode(profileData);
      await prefs.setString(_profileKey, profileJson);
    } catch (e) {
      print('Error saving to preferences: $e');
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
      print('Error saving allergen profile: $e');
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
      notifyListeners();
    } catch (e) {
      print('Error clearing allergen profile: $e');
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
      print('Error checking profile: $e');
      return false;
    }
  }
}
