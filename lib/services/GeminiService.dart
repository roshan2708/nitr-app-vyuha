// FILE: lib/services/GeminiService.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class GeminiService {
  final _firestore = FirebaseFirestore.instance;

  // Updated to Gemini 2.5 Flash (Stable)
  final String endpoint =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=";

  /// Fetches the Gemini API config from Firestore.
  /// Returns null if the document doesn't exist or data is missing.
  Future<Map<String, String>?> _fetchGeminiConfig({
    bool isFlowchart = false,
    bool isExplanation = false,
  }) async {
    try {
      final doc = await _firestore.collection('config').doc('gemini').get();

      if (!doc.exists || doc.data() == null) {
        print("Error: 'config/gemini' document not found in Firestore.");
        return null;
      }

      final data = doc.data()!;
      final apiKey = data['apiKey'] as String?;

      // Determine which prompt template to fetch
      String promptKey = 'promptTemplate'; // Default for ideas
      if (isFlowchart) {
        promptKey = 'flowchartPromptTemplate';
      } else if (isExplanation) {
        promptKey = 'explainPromptTemplate';
      }

      final promptTemplate = data[promptKey] as String?;

      if (apiKey == null) {
        print("Error: 'apiKey' missing from config doc.");
        return null;
      }

      // If specific template is missing, return a default or null depending on strictness
      if (promptTemplate == null) {
        // Fallback for explanation if not in DB to ensure feature works
        if (isExplanation) {
          return {
            'apiKey': apiKey,
            'promptTemplate':
                "Explain the concept of '{topic}' in the context of project planning and brainstorming. Provide an overview, key perspectives, and an actionable insight. Keep it concise.",
          };
        }
        // Fallback for flowchart
        if (isFlowchart) {
          return {
            'apiKey': apiKey,
            'promptTemplate':
                "Create a flowchart for '{topic}'. Context: '{context}'. Return ONLY valid JSON with 'nodes' (id, text, type: process|decision|start|end) and 'edges' (fromId, toId, fromAnchor, toAnchor).",
          };
        }
        print("Error: '$promptKey' missing from config doc.");
        return null;
      }

      return {'apiKey': apiKey, 'promptTemplate': promptTemplate};
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
            {"text": prompt},
          ],
        },
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
          // Cleanup markdown list items if present (e.g., "* Idea" or "1. Idea")
          var cleanLine = l.replaceAll(RegExp(r'^[\*\-\d\.]+\s+'), '');

          if (!unique.contains(cleanLine) && cleanLine.isNotEmpty) {
            unique.add(cleanLine);
            out.add(cleanLine);
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

  /// Generates an explanation for a node.
  Future<String> generateExplanation(String topic) async {
    // 1. Fetch config (flag isExplanation: true)
    final config = await _fetchGeminiConfig(isExplanation: true);
    if (config == null) {
      throw Exception("Configuration or API Key missing.");
    }

    final apiKey = config['apiKey']!;
    final promptTemplate = config['promptTemplate']!;

    // 2. Build prompt
    final prompt = promptTemplate.replaceAll('{topic}', topic);

    // 3. Build request
    final url = Uri.parse(endpoint + apiKey);
    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    };

    // 4. API Call
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (res.statusCode == 200) {
        final map = json.decode(res.body);
        if (map['candidates'] != null &&
            map['candidates'][0]['content'] != null &&
            map['candidates'][0]['content']['parts'] != null) {
          final parts = map['candidates'][0]['content']['parts'];
          final text = parts.map((p) => p['text']).join('\n');
          return text;
        }
        throw Exception("Empty response from AI");
      } else {
        throw Exception("AI Error: ${res.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch explanation: $e");
    }
  }

  /// Generates a flowchart as a JSON string.
  /// [flowchartType] can be: technical, marketing, business, product, education, custom
  Future<String> generateKramFlowchart(
    String topic,
    String context, {
    String flowchartType = 'custom',
  }) async {
    // 1. Fetch config from Firestore
    final config = await _fetchGeminiConfig(isFlowchart: true);
    if (config == null) {
      throw Exception("Flowchart configuration not found in Firestore.");
    }

    final apiKey = config['apiKey']!;

    // 2. Build a comprehensive type-aware prompt
    final typeGuidance = _getTypeGuidance(flowchartType);

    final prompt =
        '''
You are an expert flowchart architect. Generate a professional, well-structured $flowchartType flowchart for: "$topic".

Context: $context

$typeGuidance

═══════════════════════════════════════
STRICT STRUCTURAL RULES (follow exactly):
═══════════════════════════════════════
1. Return ONLY raw JSON — no markdown fences, no explanation text.
2. Generate exactly 10-14 nodes for a comprehensive, detailed flowchart.
3. Node IDs must be simple sequential strings: "n1", "n2", "n3", etc.
4. EXACTLY ONE "start" node (id: "n1") and ONE or TWO "end" nodes.
5. Use "decision" nodes for binary branching (Yes/No). Each decision has exactly 2 outgoing edges.
6. Use "process" nodes for all action/step nodes.
7. Node text: 3-7 words, clear and action-oriented (e.g., "Validate User Input", "Send Confirmation Email").
8. Every node must be reachable from the start node — no orphans.
9. Edges: use fromAnchor="bottom" toAnchor="top" for straight-down flow (default).
10. Decision YES branch: fromAnchor="bottom", toAnchor="top".
11. Decision NO branch: fromAnchor="right", toAnchor="top" (goes to a different node on the right).
12. NO duplicate edges (same fromId + toId pair must appear at most once).
13. NO self-loops (fromId must never equal toId).
14. The graph must be a DAG (directed acyclic graph) — no cycles.

═══════════════════════════════════════
REQUIRED JSON FORMAT:
═══════════════════════════════════════
{
  "nodes": [
    {"id": "n1", "text": "Start", "type": "start"},
    {"id": "n2", "text": "Receive Request", "type": "process"},
    {"id": "n3", "text": "Is Valid?", "type": "decision"},
    {"id": "n4", "text": "Process Request", "type": "process"},
    {"id": "n5", "text": "Return Error", "type": "process"},
    {"id": "n6", "text": "Send Response", "type": "process"},
    {"id": "n7", "text": "End", "type": "end"}
  ],
  "edges": [
    {"fromId": "n1", "toId": "n2", "fromAnchor": "bottom", "toAnchor": "top"},
    {"fromId": "n2", "toId": "n3", "fromAnchor": "bottom", "toAnchor": "top"},
    {"fromId": "n3", "toId": "n4", "fromAnchor": "bottom", "toAnchor": "top"},
    {"fromId": "n3", "toId": "n5", "fromAnchor": "right", "toAnchor": "top"},
    {"fromId": "n4", "toId": "n6", "fromAnchor": "bottom", "toAnchor": "top"},
    {"fromId": "n5", "toId": "n7", "fromAnchor": "bottom", "toAnchor": "top"},
    {"fromId": "n6", "toId": "n7", "fromAnchor": "bottom", "toAnchor": "top"}
  ]
}

Now generate the actual flowchart for "$topic". Make it specific, detailed, and domain-accurate for $flowchartType context.
''';

    // 3. Build the request
    final url = Uri.parse(endpoint + apiKey);
    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
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

        if (map['candidates'] != null &&
            map['candidates'][0]['content'] != null &&
            map['candidates'][0]['content']['parts'] != null) {
          final parts = map['candidates'][0]['content']['parts'];
          String rawJson = parts.map((p) => p['text']).join('');

          // Clean up the response
          rawJson = rawJson
              .replaceAll("```json", "")
              .replaceAll("```", "")
              .trim();

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

  /// Returns type-specific guidance for the AI prompt.
  String _getTypeGuidance(String type) {
    switch (type) {
      case 'technical':
        return '''TYPE: Technical Flowchart
Focus on: system architecture, API endpoints, data flow, error handling, authentication steps, database operations.
Use technical terminology. Include validation and error branches.''';
      case 'marketing':
        return '''TYPE: Marketing Flowchart
Focus on: customer acquisition funnel, lead generation, campaign stages, A/B testing, conversion optimization, retention loops.
Use marketing terminology. Include metrics checkpoints and decision nodes for campaign performance.''';
      case 'business':
        return '''TYPE: Business Process Flowchart
Focus on: operational workflows, approval chains, compliance checks, resource allocation, stakeholder communication.
Use business terminology. Include approval/rejection decision nodes.''';
      case 'product':
        return '''TYPE: Product Development Flowchart
Focus on: user stories, feature prioritization, sprint planning, user testing, release cycles, feedback loops.
Use product management terminology. Include user testing and iteration decision nodes.''';
      case 'education':
        return '''TYPE: Educational Flowchart
Focus on: learning paths, prerequisites, skill assessments, module progression, certification steps.
Use educational terminology. Include assessment checkpoints and remediation branches.''';
      default:
        return '''TYPE: General Flowchart
Create a clear, logical flow for the given topic. Include proper start/end points and decision branches where appropriate.''';
    }
  }
}
