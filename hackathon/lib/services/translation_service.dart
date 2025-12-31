import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal() {
    _loadCache();
  }

  static const String _apiKey = 'open-AI-key';
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _cacheKey = 'translation_cache';

  Map<String, String> _translationCache = {};

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      if (cacheJson != null) {
        _translationCache = Map<String, String>.from(jsonDecode(cacheJson));
      }
    } catch (e) {
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = jsonEncode(_translationCache);
      await prefs.setString(_cacheKey, cacheJson);
    } catch (e) {
    }
  }

  Future<List<String>> translateIngredients(List<String> ingredients) async {
    if (ingredients.isEmpty) return ingredients;

    final List<String> translated = [];
    final List<String> toTranslate = [];

    for (var ingredient in ingredients) {
      if (_translationCache.containsKey(ingredient)) {
        translated.add(_translationCache[ingredient]!);
      } else {
        toTranslate.add(ingredient);
      }
    }

    if (toTranslate.isEmpty) {
      return translated;
    }

    try {
      final translatedBatch = await _translateWithAI(toTranslate);

      for (int i = 0; i < toTranslate.length; i++) {
        final original = toTranslate[i];
        final translatedText = translatedBatch[i];
        _translationCache[original] = translatedText;
        translated.add(translatedText);
      }

      await _saveCache();
    } catch (e) {
      translated.addAll(toTranslate);
    }

    return translated;
  }

  Future<String> translateIngredient(String ingredient) async {
    if (ingredient.isEmpty) return ingredient;

    if (_translationCache.containsKey(ingredient)) {
      return _translationCache[ingredient]!;
    }

    try {
      final translated = await _translateWithAI([ingredient]);
      final result = translated.isNotEmpty ? translated[0] : ingredient;

      _translationCache[ingredient] = result;
      await _saveCache();

      return result;
    } catch (e) {
      return ingredient;
    }
  }

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

      final translatedList = translatedText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (translatedList.length == ingredients.length) {
        return translatedList;
      } else {
        return translatedList.length > 0 ? translatedList : ingredients;
      }
    } else {
      throw Exception('Translation API error: ${response.statusCode}');
    }
  }

  Future<String> translateMedicalCondition(String condition) async {
    return await translateIngredient(condition);
  }

  Future<List<String>> translateList(List<String> items) async {
    if (items.isEmpty) return items;
    return await translateIngredients(items);
  }

  Future<String> translateText(String text) async {
    if (text.isEmpty) return text;

    final vietnamesePattern = RegExp(r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]', caseSensitive: false);
    if (vietnamesePattern.hasMatch(text)) {
      return text;
    }

    return await translateIngredient(text);
  }

  static bool matchesAllergen(String ingredient, String allergen) {
    final normalize = (String text) => text.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');

    final normalizedIngredient = normalize(ingredient);
    final normalizedAllergen = normalize(allergen);

    if (normalizedIngredient.contains(normalizedAllergen)) return true;

    final allergenWords = normalizedAllergen.split(RegExp(r'[\s,]+'));
    for (var word in allergenWords) {
      if (word.isNotEmpty && normalizedIngredient.contains(word)) {
        return true;
      }
    }

    final ingredientWords = normalizedIngredient.split(RegExp(r'[\s,]+'));
    for (var word in ingredientWords) {
      if (word.isNotEmpty && normalizedAllergen.contains(word)) {
        return true;
      }
    }

    return false;
  }
}
