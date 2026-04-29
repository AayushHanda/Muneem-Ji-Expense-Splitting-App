import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AIAssistantService {
  static const String _defaultApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyDwP9YZw9xqgiXUht9EzY5XriroBJ1u4eA',
  );

  static const String _model = 'gemini-2.5-flash';

  Future<String> generateResponse(String userPrompt, String contextData) async {
    if (_defaultApiKey.isEmpty) {
      return "⚠️ **Gemini API Key missing.**\nTo enable Muneem Ji Chat, please add your Google AI API key.";
    }

    final systemPrompt = """
You are 'Muneem Ji', a personal financial assistant AI.
Your goal is to help users understand their expenses, debts, and budgets based on the financial data provided.

Rules:
1. Be polite, concise, and helpful.
2. If the user asks about their balance with someone, use the 'USER FINANCIAL CONTEXT' provided.
3. If they ask about spending trends, use the context to look at dates and categories.
4. Format your response clearly with bullet points or bold text where appropriate.
5. If the context doesn't have the answer, say so honestly.

$contextData
""";

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_defaultApiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$systemPrompt\n\nUser Question: $userPrompt'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      },
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text ?? "I'm sorry, I couldn't generate a response.";
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']?['message'] ?? 'Unknown error';
        debugPrint('Gemini API Error (${response.statusCode}): $errorMsg');
        return "Error (${response.statusCode}): $errorMsg";
      }
    } catch (e) {
      debugPrint('Gemini Error: $e');
      return "I encountered an error:\n\n$e\n\nPlease check your connection.";
    }
  }
}
