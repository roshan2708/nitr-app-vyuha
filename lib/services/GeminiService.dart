import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class GeminiService {
  final _firestore = FirebaseFirestore.instance;

  // ✅ Correct endpoint for Gemini 1.5 model
  final String endpoint =
      "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=";

  /// Fetches the Gemini API config from Firestore.
  /// Returns null if the document doesn't exist or data is missing.
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
    // 1. Fetch config from Firestore
    final config = await _fetchGeminiConfig();
    if (config == null) {
      return []; // Return empty if config failed to load
    }

    final apiKey = config['apiKey']!;
    final promptTemplate = config['promptTemplate']!;

    // 2. Build the prompt from the template
    final prompt = promptTemplate
        .replaceAll('{count}', count.toString())
        .replaceAll('{topic}', topic);

    // 3. Build the request
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

    // 4. Make the API call
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
            if (out.length >= count) break;
          }
        }
        return out;
      } else {
        print("Gemini error: ${res.statusCode} ${res.body}");
        // You might want to check for 401/403 errors, which could
        // indicate the API key from Firestore is wrong.
        return [];
      }
    } catch (e) {
      print("Gemini request exception: $e");
      return [];
    }
  }
}