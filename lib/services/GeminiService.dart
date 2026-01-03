import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class GeminiService {
  final _firestore = FirebaseFirestore.instance;

  // ✅ Correct endpoint for Gemini 2.5 Flash model
  final String endpoint =
      "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=";

  /// Fetches the Gemini API config from Firestore.
  Future<Map<String, String>?> _fetchGeminiConfig() async {
    try {
      final doc =
          await _firestore.collection('config').doc('gemini').get();

      if (!doc.exists || doc.data() == null) {
        print("Error: 'config/gemini' document not found in Firestore.");
        return null;
      }

      final data = doc.data()!;
      final apiKey = data['apiKey'] as String?;
      final promptTemplate = data['promptTemplate'] as String?;

      if (apiKey == null || promptTemplate == null) {
        print("Error: 'apiKey' or 'promptTemplate' missing from config doc.");
        return null;
      }

      return {
        'apiKey': apiKey,
        'promptTemplate': promptTemplate,
      };
    } catch (e) {
      print("Firestore config fetch exception: $e");
      return null;
    }
  }

  Future<List<String>> generateIdeas(String topic, {int count = 5}) async {
    final config = await _fetchGeminiConfig();
    if (config == null) return [];

    final apiKey = config['apiKey']!;
    final promptTemplate = config['promptTemplate']!;

    final prompt = promptTemplate
        .replaceAll('{count}', count.toString())
        .replaceAll('{topic}', topic);

    // --- FIX START ---
    // Await the request to get the dynamic result
    final result = await _makeRequest(apiKey, prompt, isList: true);
    
    // Safely convert dynamic List to List<String>
    if (result is List) {
      return List<String>.from(result);
    }
    return [];
    // --- FIX END ---
  }

  // --- Method for AI Explain ---
  Future<String> explainNode(String text) async {
    final config = await _fetchGeminiConfig();
    if (config == null) return "Configuration Error";

    final apiKey = config['apiKey']!;
    // Simple direct prompt for explanation
    final prompt = "Explain the following concept in simple, structured terms suitable for a mind map or study notes. Keep it under 200 words:\n\n$text";

    final result = await _makeRequest(apiKey, prompt, isList: false);
    return result as String;
  }

  // Helper to reduce code duplication
  Future<dynamic> _makeRequest(String apiKey, String prompt, {required bool isList}) async {
    final url = Uri.parse(endpoint + apiKey);
    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    };

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (res.statusCode == 200) {
        final map = json.decode(res.body);
        String text = '';
        if (map['candidates'] != null &&
            map['candidates'][0]['content'] != null &&
            map['candidates'][0]['content']['parts'] != null) {
          final parts = map['candidates'][0]['content']['parts'];
          text = parts.map((p) => p['text']).join('\n');
        }

        if (isList) {
          final lines = text
              .split(RegExp(r'\r?\n'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          
          final unique = <String>{};
          final out = <String>[];
          for (var l in lines) {
            if (!unique.contains(l)) {
              unique.add(l);
              out.add(l);
            }
          }
          return out;
        } else {
          return text;
        }
      } else {
        print("Gemini error: ${res.statusCode} ${res.body}");
        return isList ? <String>[] : "Error from AI Service";
      }
    } catch (e) {
      print("Gemini request exception: $e");
      return isList ? <String>[] : "Connection Error";
    }
  }
}