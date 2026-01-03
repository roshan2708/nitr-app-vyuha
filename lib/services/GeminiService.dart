// FILE: lib/services/GeminiService.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class GeminiService {
  final _firestore = FirebaseFirestore.instance;

  // --- FIX IS HERE: Using v1beta and gemini-2.5-flash ---
  final String endpoint =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=";

  /// Fetches the Gemini API config from Firestore.
  /// Returns null if the document doesn't exist or data is missing.
  Future<Map<String, String>?> _fetchGeminiConfig(
      {bool isFlowchart = false}) async {
    try {
      final doc =
          await _firestore.collection('config').doc('gemini').get();

      if (!doc.exists || doc.data() == null) {
        print("Error: 'config/gemini' document not found in Firestore.");
        return null;
      }

      final data = doc.data()!;
      final apiKey = data['apiKey'] as String?;
      
      // (MODIFIED) Select the correct prompt template
      final String promptKey = isFlowchart ? 'flowchartPromptTemplate' : 'promptTemplate';
      final promptTemplate = data[promptKey] as String?;

      if (apiKey == null || promptTemplate == null) {
        print("Error: 'apiKey' or '$promptKey' missing from config doc.");
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
    final config = await _fetchGeminiConfig(isFlowchart: false); // isFlowchart: false
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
      ],
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
        return [];
      }
    } catch (e) {
      print("Gemini request exception: $e");
      return [];
    }
  }

  // --- NEW METHOD FOR KRAM ---

  /// Generates a flowchart as a JSON string.
  Future<String> generateKramFlowchart(String topic, String context) async {
    // 1. Fetch config from Firestore
    final config = await _fetchGeminiConfig(isFlowchart: true); // isFlowchart: true
    if (config == null) {
      throw Exception("Flowchart configuration not found in Firestore.");
    }

    final apiKey = config['apiKey']!;
    final promptTemplate = config['promptTemplate']!;

    // 2. Build the prompt from the template
    final prompt = promptTemplate
        .replaceAll('{topic}', topic)
        .replaceAll('{context}', context.replaceAll('"', r'\"')); // Escape quotes

    // 3. Build the request
    final url = Uri.parse(endpoint + apiKey);
    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ],
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
        
        // Extract the raw text from the response
        if (map['candidates'] != null &&
            map['candidates'][0]['content'] != null &&
            map['candidates'][0]['content']['parts'] != null) {
          final parts = map['candidates'][0]['content']['parts'];
          String rawJson = parts.map((p) => p['text']).join('');
          
          // Clean up the response (Gemini sometimes wraps in markdown)
          rawJson = rawJson.replaceAll("```json", "").replaceAll("```", "").trim();
          
          // Return the raw JSON string
          return rawJson;
        }
        
        throw Exception("Failed to parse Gemini response.");
      } else {
        print("Gemini error: ${res.statusCode} ${res.body}");
        throw Exception("Gemini API error: ${res.body}");
      }
    } catch (e) {
      print("Gemini request exception: $e");
      throw Exception("Failed to call Gemini: $e");
    }
  }
}