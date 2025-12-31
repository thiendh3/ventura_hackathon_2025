import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal() {
    // Load cache asynchronously (fire-and-forget)
    _loadCache();
  }

  static const String _apiKey = 'open-AI-key';
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _cacheKey = 'translation_cache';

  // Cache for translations to avoid repeated API calls
  Map<String, String> _translationCache = {};

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      if (cacheJson != null) {
        _translationCache = Map<String, String>.from(jsonDecode(cacheJson));
      }
    } catch (e) {
      // Cache load failed, will use empty cache
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = jsonEncode(_translationCache);
      await prefs.setString(_cacheKey, cacheJson);
    } catch (e) {
      // Cache save failed, continue without caching
    }
  }

  /// Translate ingredients using AI
  Future<List<String>> translateIngredients(List<String> ingredients) async {
    if (ingredients.isEmpty) return ingredients;

    // Check cache first
    final List<String> translated = [];
    final List<String> toTranslate = [];

    for (var ingredient in ingredients) {
      if (_translationCache.containsKey(ingredient)) {
        translated.add(_translationCache[ingredient]!);
      } else {
        toTranslate.add(ingredient);
      }
    }

    // If all are cached, return immediately
    if (toTranslate.isEmpty) {
      return translated;
    }

    // Translate remaining ingredients using AI
    try {
      final translatedBatch = await _translateWithAI(toTranslate);

      // Update cache and add to result
      for (int i = 0; i < toTranslate.length; i++) {
        final original = toTranslate[i];
        final translatedText = translatedBatch[i];
        _translationCache[original] = translatedText;
        translated.add(translatedText);
      }

      // Save cache
      await _saveCache();
    } catch (e) {
      // Fallback to original if translation fails
      translated.addAll(toTranslate);
    }

    return translated;
  }

  /// Translate a single ingredient using AI
  Future<String> translateIngredient(String ingredient) async {
    if (ingredient.isEmpty) return ingredient;

    // Check cache
    if (_translationCache.containsKey(ingredient)) {
      return _translationCache[ingredient]!;
    }

    try {
      final translated = await _translateWithAI([ingredient]);
      final result = translated.isNotEmpty ? translated[0] : ingredient;

      // Cache result
      _translationCache[ingredient] = result;
      await _saveCache();

      return result;
    } catch (e) {
      return ingredient;
    }
  }

  /// Translate using OpenAI API
  Future<List<String>> _translateWithAI(List<String> ingredients) async {
    final ingredientsText = ingredients.join(', ');

    final messages = [
      {
        'role': 'system',
        'content': '''Bạn là một dịch giả chuyên nghiệp. Nhiệm vụ của bạn là dịch tên các thành phần thực phẩm (ingredients) từ bất kỳ ngôn ngữ nào (tiếng Anh, tiếng Thái, tiếng Nhật, v.v.) sang tiếng Việt.

QUAN TRỌNG:
- Dịch CHÍNH XÁC tên thành phần sang tiếng Việt
- Giữ nguyên tên riêng nếu không có bản dịch phù hợp
- Nếu thành phần là một câu (ví dụ: "không có sữa"), dịch toàn bộ câu
- Trả về danh sách các thành phần đã dịch, phân cách bằng dấu phẩy
- KHÔNG thêm bất kỳ text nào khác, chỉ trả về danh sách thành phần đã dịch

Ví dụ:
Input: "milk, eggs, นม, ไม่มี นม"
Output: "Sữa, Trứng, Sữa, Không có sữa"''',
      },
      {
        'role': 'user',
        'content': 'Dịch các thành phần sau sang tiếng Việt: $ingredientsText',
      },
    ];

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': messages,
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      final translatedText = jsonResponse['choices'][0]['message']['content'] as String;

      // Parse the translated ingredients
      final translatedList = translatedText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Ensure we return the same number of items
      if (translatedList.length == ingredients.length) {
        return translatedList;
      } else {
        // If count doesn't match, try to split differently or return original
        return translatedList.length > 0 ? translatedList : ingredients;
      }
    } else {
      throw Exception('Translation API error: ${response.statusCode}');
    }
  }

  /// Translate medical condition using AI
  Future<String> translateMedicalCondition(String condition) async {
    // Use the same translation method as ingredients
    return await translateIngredient(condition);
  }

  /// Translate a list of strings (allergens, medical history, etc.) to Vietnamese
  Future<List<String>> translateList(List<String> items) async {
    if (items.isEmpty) return items;
    return await translateIngredients(items);
  }

  /// Translate skin type, health goal, or other single text value to Vietnamese
  /// Returns original if already in Vietnamese or if translation fails
  Future<String> translateText(String text) async {
    if (text.isEmpty) return text;

    // Check if text contains Vietnamese characters
    final vietnamesePattern = RegExp(r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]', caseSensitive: false);
    if (vietnamesePattern.hasMatch(text)) {
      // Already contains Vietnamese characters, likely already in Vietnamese
      return text;
    }

    // Try to translate
    return await translateIngredient(text);
  }

  /// Check if an ingredient matches an allergen (for health warning matching)
  /// This handles multi-language matching
  static bool matchesAllergen(String ingredient, String allergen) {
    // Normalize for comparison (remove spaces, convert to lowercase)
    final normalize = (String text) => text.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');

    final normalizedIngredient = normalize(ingredient);
    final normalizedAllergen = normalize(allergen);

    // Direct match
    if (normalizedIngredient.contains(normalizedAllergen)) return true;

    // Check if allergen is in ingredient (case insensitive, space-insensitive)
    final allergenWords = normalizedAllergen.split(RegExp(r'[\s,]+'));
    for (var word in allergenWords) {
      if (word.isNotEmpty && normalizedIngredient.contains(word)) {
        return true;
      }
    }

    // Check reverse
    final ingredientWords = normalizedIngredient.split(RegExp(r'[\s,]+'));
    for (var word in ingredientWords) {
      if (word.isNotEmpty && normalizedAllergen.contains(word)) {
        return true;
      }
    }

    return false;
  }
}
