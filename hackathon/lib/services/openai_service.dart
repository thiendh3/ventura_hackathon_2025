import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _apiKey = 'open-AI-key';
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String> chatCompletion(List<Map<String, String>> messages) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': messages,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception('OpenAI API error: ${errorData['error']?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
