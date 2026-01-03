
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:vyuha/controllers/AuthController.dart';
import 'package:vyuha/models/KramModels.dart';
import 'package:vyuha/services/GeminiService.dart';

class KramController extends GetxController {
  final String roomId;
  KramController(this.roomId);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final gemini = GeminiService();
  
  // Auth Info
  final uid = Get.find<AuthController>().uid;
  String _userName = 'User'; // Will be fetched

  // Collections
  late final CollectionReference flowRef;
  late final CollectionReference notesRef;

  // Observables
  final RxList<KramFlowElement> flowElements = <KramFlowElement>[].obs;
  final RxList<KramNote> stickyNotes = <KramNote>[].obs;
  
  // AI Explain State
  final RxString selectedNodeForExplanation = ''.obs;
  final RxString aiExplanationResult = ''.obs;
  final RxBool isExplaining = false.obs;

  @override
  void onInit() {
    super.onInit();
    final roomRef = _firestore.collection('rooms').doc(roomId);
    flowRef = roomRef.collection('kram_flowchart');
    notesRef = roomRef.collection('kram_notes');
    
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

  // --- AI Logic ---

  Future<void> explainNodeText(String text) async {
    if (text.isEmpty) return;
    isExplaining.value = true;
    aiExplanationResult.value = ''; // Clear previous
    try {
      final result = await gemini.explainNode(text);
      aiExplanationResult.value = result;
    } catch (e) {
      aiExplanationResult.value = "Failed to explain: $e";
    } finally {
      isExplaining.value = false;
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
    // Optimistic update for smoothness
    final index = flowElements.indexWhere((e) => e.id == id);
    if (index != -1) {
      flowElements[index] = KramFlowElement(
        id: flowElements[index].id,
        text: flowElements[index].text,
        x: x,
        y: y,
        type: flowElements[index].type,
        connections: flowElements[index].connections,
      );
      flowElements.refresh();
    }
    // Fire and forget update
    await flowRef.doc(id).update({'x': x, 'y': y});
  }

  Future<void> updateFlowElementText(String id, String newText) async {
    await flowRef.doc(id).update({'text': newText});
  }

  Future<void> deleteFlowElement(String id) async {
    await flowRef.doc(id).delete();
  }

  Future<void> toggleConnection(String fromId, String toId) async {
    if (fromId == toId) return; // No self loops for simplicity

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
    // Optimistic
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
