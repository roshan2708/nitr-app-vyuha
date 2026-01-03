import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:vyuha/controllers/AuthController.dart';
import 'package:vyuha/models/KramModels.dart';
import 'package:vyuha/services/GeminiService.dart';

class KramController extends GetxController {
  final String roomId;
  final String nodeId; // Specific Node ID
  final String initialTopic; // Topic to generate if empty

  KramController({
    required this.roomId,
    required this.nodeId,
    required this.initialTopic,
  });

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final gemini = GeminiService();
  
  // Auth Info
  final uid = Get.find<AuthController>().uid;
  String _userName = 'User';

  // Collections
  late final CollectionReference flowRef;
  late final CollectionReference notesRef;

  // Observables
  final RxList<KramFlowElement> flowElements = <KramFlowElement>[].obs;
  final RxList<KramNote> stickyNotes = <KramNote>[].obs;
  
  final RxBool isGenerating = false.obs;
  final RxString statusMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Data is now nested under the specific Node
    final nodeRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('nodes')
        .doc(nodeId);
        
    flowRef = nodeRef.collection('kram_flowchart');
    notesRef = nodeRef.collection('kram_notes');
    
    _fetchUserName();
    _listenFlowchart();
    _listenNotes();
  }

  Future<void> _fetchUserName() async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _userName = doc.get('name') ?? 'User';
      }
    } catch (_) {}
  }

  // --- AI Flowchart Generation ---

  Future<void> generateFlowchart() async {
    if (flowElements.isNotEmpty) {
      // Don't overwrite existing work without explicit clear, 
      // but for now, we just return or maybe append. 
      // Let's return to avoid accidental data loss.
      statusMessage.value = "Canvas not empty. Clear to regenerate.";
      return;
    }

    isGenerating.value = true;
    statusMessage.value = "AI is designing flowchart...";

    try {
      // 1. Ask Gemini for Structure (Mocking the prompt string logic here)
      // You would normally pass this prompt to gemini.generateText(prompt)
      final prompt = """
      Create a flowchart for the process: "$initialTopic".
      Return ONLY valid JSON. No markdown formatting.
      Structure:
      {
        "steps": [
          {"id": "1", "text": "Start", "type": "oval"},
          {"id": "2", "text": "Step description", "type": "rectangle"},
          {"id": "3", "text": "Decision?", "type": "diamond"}
        ],
        "connections": [
          {"from": "1", "to": "2"},
          {"from": "2", "to": "3"}
        ]
      }
      Make it detailed with at least 5-7 steps.
      """;

      // Call your Gemini Service
      // NOTE: Ensure your GeminiService has a method that returns String
      final jsonString = await gemini.explainNode(prompt); 
      
      // Clean up string if it contains markdown code blocks
      String cleanJson = jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final data = jsonDecode(cleanJson);
      final List<dynamic> steps = data['steps'];
      final List<dynamic> connections = data['connections'];

      // 2. Convert to Firestore Batches
      final batch = _firestore.batch();
      
      // Simple Layout Algorithm (Vertical Flow)
      double currentY = 100.0;
      double centerX = 300.0; // Assume canvas centerish
      
      Map<String, KramFlowElement> elementMap = {};

      for (var step in steps) {
        final String rawId = step['id'].toString();
        final String firestoreId = Uuid().v4(); // Generate clean ID
        
        // Store mapping from JSON ID to Firestore ID
        // (This is a simplified approach, in reality, use a map)
        // For simplicity, we just use the index if IDs are numeric, 
        // but here we must map properly.
        
        FlowShapeType type = FlowShapeType.rectangle;
        if (step['type'] == 'oval') type = FlowShapeType.oval;
        if (step['type'] == 'diamond') type = FlowShapeType.diamond;

        final el = KramFlowElement(
          id: firestoreId,
          text: step['text'],
          x: centerX,
          y: currentY,
          type: type,
          connections: [],
        );
        
        // Add to map for connection linking later (using rawId as key is tricky 
        // if we change ID, so we need a lookup map)
        elementMap[rawId] = el;
        
        currentY += 150.0; // Spacing
      }

      // 3. Link Connections
      for (var conn in connections) {
        final fromId = conn['from'].toString();
        final toId = conn['to'].toString();
        
        if (elementMap.containsKey(fromId) && elementMap.containsKey(toId)) {
          final fromEl = elementMap[fromId]!;
          final toEl = elementMap[toId]!;
          
          fromEl.connections.add(toEl.id);
        }
      }

      // 4. Commit to DB
      for (var el in elementMap.values) {
        final docRef = flowRef.doc(el.id);
        batch.set(docRef, el.toMap());
      }

      await batch.commit();
      statusMessage.value = "";

    } catch (e) {
      statusMessage.value = "Error generating: $e";
      print(e);
    } finally {
      isGenerating.value = false;
    }
  }

  // --- Flowchart Logic ---

  void _listenFlowchart() {
    flowRef.snapshots().listen((snap) {
      final list = snap.docs.map((d) {
        return KramFlowElement.fromMap(d.data() as Map<String, dynamic>);
      }).toList();
      flowElements.assignAll(list);
    });
  }

  Future<void> addFlowElement(FlowShapeType type, double x, double y) async {
    final id = Uuid().v4();
    final el = KramFlowElement(
      id: id,
      text: 'New Step',
      x: x,
      y: y,
      type: type,
    );
    await flowRef.doc(id).set(el.toMap());
  }

  Future<void> updateFlowElementPosition(String id, double x, double y) async {
    // Optimistic update
    final index = flowElements.indexWhere((e) => e.id == id);
    if (index != -1) {
      final old = flowElements[index];
      flowElements[index] = KramFlowElement(
        id: old.id,
        text: old.text,
        x: x,
        y: y,
        type: old.type,
        connections: old.connections
      );
      flowElements.refresh();
    }
    // Fire and forget
    await flowRef.doc(id).update({'x': x, 'y': y});
  }

  Future<void> updateFlowElementText(String id, String newText) async {
    await flowRef.doc(id).update({'text': newText});
  }

  Future<void> deleteFlowElement(String id) async {
    await flowRef.doc(id).delete();
  }

  Future<void> toggleConnection(String fromId, String toId) async {
    if (fromId == toId) return;

    final doc = await flowRef.doc(fromId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    List<String> conns = List<String>.from(data['connections'] ?? []);

    if (conns.contains(toId)) {
      conns.remove(toId);
    } else {
      conns.add(toId);
    }

    await flowRef.doc(fromId).update({'connections': conns});
  }

  Future<void> clearCanvas() async {
     final batch = _firestore.batch();
     final snaps = await flowRef.get();
     for(var doc in snaps.docs) {
       batch.delete(doc.reference);
     }
     await batch.commit();
  }

  // --- Sticky Notes Logic ---

  void _listenNotes() {
    notesRef.snapshots().listen((snap) {
      final list = snap.docs.map((d) {
        return KramNote.fromMap(d.data() as Map<String, dynamic>);
      }).toList();
      stickyNotes.assignAll(list);
    });
  }

  Future<void> addNote(double x, double y, int colorIndex) async {
    final id = Uuid().v4();
    final note = KramNote(
      id: id,
      content: '',
      x: x,
      y: y,
      authorName: _userName,
      authorId: uid,
      colorIndex: colorIndex,
    );
    await notesRef.doc(id).set(note.toMap());
  }

  Future<void> updateNotePosition(String id, double x, double y) async {
    final index = stickyNotes.indexWhere((n) => n.id == id);
    if (index != -1) {
       final old = stickyNotes[index];
       stickyNotes[index] = KramNote(id: old.id, content: old.content, x: x, y: y, authorName: old.authorName, authorId: old.authorId, colorIndex: old.colorIndex);
       stickyNotes.refresh();
    }
    await notesRef.doc(id).update({'x': x, 'y': y});
  }

  Future<void> updateNoteContent(String id, String content) async {
    await notesRef.doc(id).update({'content': content});
  }

  Future<void> deleteNote(String id) async {
    await notesRef.doc(id).delete();
  }
}