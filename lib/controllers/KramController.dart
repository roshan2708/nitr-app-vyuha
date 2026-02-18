// FILE: lib/controllers/KramController.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:vyuha/controllers/AuthController.dart';
import 'package:vyuha/models/CollaboratorModel.dart';
import 'package:vyuha/models/KramModel.dart';
import 'package:vyuha/services/GeminiService.dart';
import 'dart:math';

// --- UNDO/REDO MEMENTO ---
abstract class IKramMemento {
  void execute(); // Redo
  void unexecute(); // Undo
}

// --- ENUMS ---
enum AnchorSide { top, right, bottom, left }

class KramController extends GetxController {
  final String roomId;
  KramController(this.roomId);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxList<KramElementModel> elements = <KramElementModel>[].obs;
  final RxList<KramEdgeModel> edges = <KramEdgeModel>[].obs;

  final RxList<KramNoteModel> notes = <KramNoteModel>[].obs;
  final RxList<KramCommentModel> comments = <KramCommentModel>[].obs;

  final RxString roomTitle = 'Untitled Kram'.obs;
  final RxString passkey = ''.obs;
  final RxBool isOwner = false.obs;
  final RxList<CollaboratorModel> collaborators = <CollaboratorModel>[].obs;
  final RxList<CollaboratorModel> bannedUsers = <CollaboratorModel>[].obs;

  // REMOVED: final gemini = GeminiService();
  // We instantiate this locally to prevent history accumulation.

  final authController = Get.find<AuthController>();
  late final String uid;
  late final DocumentReference roomRef;
  late final CollectionReference elementsRef;
  late final CollectionReference edgesRef;
  late final CollectionReference presenceRef;
  late final CollectionReference notesRef;
  late final CollectionReference commentsRef;

  // --- VYUHA AI LIMITS ---
  final RxInt aiUsesRemaining = 15.obs;
  final Rx<DateTime?> aiUseResetTime = Rx<DateTime?>(null);
  static const int _maxAIUses = 15;

  // --- CANVAS & UI STATE ---
  final TransformationController transformationController =
      TransformationController();
  final RxBool isGeneratingAI = false.obs;
  final RxDouble currentScale = 1.0.obs;

  // --- ADVANCED SELECTION & TOOLS ---
  final RxSet<String> selectedElementIds = <String>{}.obs;
  Map<String, Offset> _multiMoveOriginalPositions = {};
  Offset _currentMultiMoveDelta = Offset.zero;

  // --- REAL-TIME PRESENCE / CURSORS ---
  final RxMap<String, Map<String, dynamic>> activeCursors =
      <String, Map<String, dynamic>>{}.obs;
  Timer? _presenceTimer;
  Timer? _staleCursorTimer;

  // --- UNDO / REDO ---
  final RxList<IKramMemento> _undoStack = <IKramMemento>[].obs;
  final RxList<IKramMemento> _redoStack = <IKramMemento>[].obs;
  bool _isUndoingOrRedoing = false;
  RxBool get canUndo => _undoStack.isNotEmpty.obs;
  RxBool get canRedo => _redoStack.isNotEmpty.obs;

  @override
  void onInit() {
    super.onInit();
    uid = authController.uid;
    roomRef = _firestore.collection('rooms').doc(roomId);
    elementsRef = roomRef.collection('elements');
    edgesRef = roomRef.collection('edges');
    presenceRef = roomRef.collection('presence');
    notesRef = roomRef.collection('notes');
    commentsRef = roomRef.collection('comments');

    _listenToRoomInfo();
    _listenToElements();
    _listenToEdges();
    _listenToNotes();
    _listenToComments();
    _listenToPresence();
    _startPresenceTimers();
  }

  @override
  void onClose() {
    _presenceTimer?.cancel();
    _staleCursorTimer?.cancel();
    if (uid.isNotEmpty) {
      presenceRef.doc(uid).delete();
    }
    transformationController.dispose();
    super.onClose();
  }

  void _listenToRoomInfo() {
    roomRef.snapshots().listen((snap) async {
      if (!snap.exists) {
        Get.offAllNamed('/home');
        return;
      }

      final data = snap.data() as Map<String, dynamic>? ?? {};

      roomTitle.value = data['title'] ?? 'Untitled Kram';
      passkey.value = data['passkey'] ?? '';
      final owner = data['owner'] ?? '';
      isOwner.value = owner == uid;

      // Check if AI generation is requested via Firestore flags
      if (data.containsKey('generationContext') &&
          data.containsKey('generationTopic')) {
        final flowchartType = data['flowchartType'] as String? ?? 'custom';
        _generateKramFromAI(
          data['generationTopic'],
          data['generationContext'],
          flowchartType: flowchartType,
        );
      }

      final int aiUses = data['aiUses'] ?? 0;
      final Timestamp? aiUseReset = data['aiUseReset'] as Timestamp?;
      final now = DateTime.now();

      if (aiUseReset == null || aiUseReset.toDate().isBefore(now)) {
        aiUsesRemaining.value = _maxAIUses;
        aiUseResetTime.value = null;
        if (aiUses > 0) {
          roomRef.update({'aiUses': 0, 'aiUseReset': null});
        }
      } else {
        aiUsesRemaining.value = (_maxAIUses - aiUses).clamp(0, _maxAIUses);
        aiUseResetTime.value = aiUseReset.toDate();
      }

      final collaboratorIds = List<String>.from(data['collaborators'] ?? []);
      await _updateCollaborators(owner, collaboratorIds);

      final bannedUserIds = List<String>.from(data['bannedUsers'] ?? []);
      await _updateBannedUsers(bannedUserIds);
    });
  }

  void _listenToElements() {
    elementsRef.snapshots().listen((snap) {
      elements.assignAll(
        snap.docs
            .map(
              (d) => KramElementModel.fromMap(d.data() as Map<String, dynamic>),
            )
            .toList(),
      );
      final allElementIds = elements.map((e) => e.id).toSet();
      selectedElementIds.removeWhere((id) => !allElementIds.contains(id));
    });
  }

  void _listenToEdges() {
    edgesRef.snapshots().listen((snap) {
      edges.assignAll(
        snap.docs
            .map((d) => KramEdgeModel.fromMap(d.data() as Map<String, dynamic>))
            .toList(),
      );
    });
  }

  void _listenToNotes() {
    notesRef.snapshots().listen((snap) {
      notes.assignAll(
        snap.docs
            .map((d) => KramNoteModel.fromMap(d.data() as Map<String, dynamic>))
            .toList(),
      );
    });
  }

  void _listenToComments() {
    commentsRef.orderBy('timestamp').snapshots().listen((snap) {
      comments.assignAll(
        snap.docs
            .map(
              (d) => KramCommentModel.fromMap(d.data() as Map<String, dynamic>),
            )
            .toList(),
      );
    });
  }

  // --- PRESENCE ---

  void _listenToPresence() {
    presenceRef.snapshots().listen((snap) {
      final now = DateTime.now();
      final updatedCursors = <String, Map<String, dynamic>>{};

      for (final doc in snap.docs) {
        if (doc.id == uid) continue;
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

        if (timestamp != null && now.difference(timestamp).inSeconds < 10) {
          updatedCursors[doc.id] = data;
        }
      }
      activeCursors.value = updatedCursors;
    });
  }

  void _startPresenceTimers() {
    _presenceTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      updateCursor(null);
    });

    _staleCursorTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      activeCursors.removeWhere(
        (key, value) => _isCursorStale(value['timestamp']),
      );
    });
  }

  bool _isCursorStale(dynamic timestamp) {
    final ts = (timestamp as Timestamp?)?.toDate();
    if (ts == null) return true;
    return DateTime.now().difference(ts).inSeconds > 10;
  }

  void updateCursor(Offset? canvasPosition) {
    if (uid.isEmpty) return;

    final data = {
      'timestamp': FieldValue.serverTimestamp(),
      'name': authController.user.value?.displayName ?? 'Guest',
      'email': authController.user.value?.email ?? '',
      if (canvasPosition != null) 'x': canvasPosition.dx,
      if (canvasPosition != null) 'y': canvasPosition.dy,
    };

    presenceRef.doc(uid).set(data, SetOptions(merge: true));
  }

  // --- UNDO / REDO ---

  void _pushToUndoStack(IKramMemento memento) {
    if (_isUndoingOrRedoing) return;
    _undoStack.add(memento);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _isUndoingOrRedoing = true;
    final memento = _undoStack.removeLast();
    memento.unexecute();
    _redoStack.add(memento);
    _isUndoingOrRedoing = false;
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _isUndoingOrRedoing = true;
    final memento = _redoStack.removeLast();
    memento.execute();
    _undoStack.add(memento);
    _isUndoingOrRedoing = false;
  }

  // --- SELECTION & MULTI-MOVE ---

  void clearSelection() => selectedElementIds.clear();
  void selectElement(String id) {
    selectedElementIds.clear();
    selectedElementIds.add(id);
  }

  void toggleSelection(String id) {
    if (selectedElementIds.contains(id)) {
      selectedElementIds.remove(id);
    } else {
      selectedElementIds.add(id);
    }
  }

  void selectElements(List<String> ids) {
    selectedElementIds.clear();
    selectedElementIds.addAll(ids);
  }

  void selectElementsInRect(Rect rect) {
    final idsInRect = <String>[];
    for (final el in elements) {
      final elRect = Rect.fromLTWH(el.x, el.y, el.width, el.height);
      if (rect.overlaps(elRect)) {
        idsInRect.add(el.id);
      }
    }
    selectedElementIds.clear();
    selectedElementIds.addAll(idsInRect);
  }

  void startMultiMove() {
    if (selectedElementIds.isEmpty) return;
    _multiMoveOriginalPositions = {
      for (final id in selectedElementIds)
        id: Offset(
          elements.firstWhere((el) => el.id == id).x,
          elements.firstWhere((el) => el.id == id).y,
        ),
    };
    _currentMultiMoveDelta = Offset.zero;
  }

  void updateMultiMove(Offset dragDelta) {
    if (_multiMoveOriginalPositions.isEmpty) return;
    _currentMultiMoveDelta += dragDelta;

    for (final id in selectedElementIds) {
      final originalPos = _multiMoveOriginalPositions[id];
      if (originalPos == null) continue;
      final newPos = originalPos + _currentMultiMoveDelta;
      final index = elements.indexWhere((el) => el.id == id);
      if (index != -1) {
        final el = elements[index];
        elements[index] = el.copyWith(x: newPos.dx, y: newPos.dy);
      }
    }
  }

  Future<void> endMultiMove() async {
    if (_multiMoveOriginalPositions.isEmpty) return;

    final batch = _firestore.batch();
    final memento = BatchMoveMemento([], this);

    for (final id in selectedElementIds) {
      final originalPos = _multiMoveOriginalPositions[id];
      if (originalPos == null) continue;
      final newPos = originalPos + _currentMultiMoveDelta;

      batch.update(elementsRef.doc(id), {'x': newPos.dx, 'y': newPos.dy});
      memento.moves.add(ElementMove(id, newPos, originalPos, this));
    }

    await batch.commit();
    _pushToUndoStack(memento);
    _multiMoveOriginalPositions.clear();
    _currentMultiMoveDelta = Offset.zero;
  }

  // --- AI GENERATION ---

  // Helper to remove markdown fences if Gemini adds them
  String _cleanJsonString(String raw) {
    raw = raw.trim();
    if (raw.startsWith('```json')) {
      raw = raw.replaceFirst('```json', '');
    } else if (raw.startsWith('```')) {
      raw = raw.replaceFirst('```', '');
    }

    // Using substring instead of replaceLast for compatibility
    if (raw.endsWith('```')) {
      raw = raw.substring(0, raw.length - 3);
    }

    return raw.trim();
  }

  Future<void> _generateKramFromAI(
    String topic,
    String context, {
    String flowchartType = 'custom',
  }) async {
    // 1. Guard against concurrent executions (e.g. from rapid snapshot updates)
    if (isGeneratingAI.value) return;

    isGeneratingAI.value = true;
    try {
      if (aiUsesRemaining.value <= 0) {
        String resetMsg = 'Resets soon.';
        if (aiUseResetTime.value != null) {
          final hours = aiUseResetTime.value!
              .difference(DateTime.now())
              .inHours;
          resetMsg = 'Resets in ~${hours}h.';
        }
        throw Exception('AI limit reached. $resetMsg');
      }

      // 2. Instantiate locally to ensure stateless request
      final gemini = GeminiService();

      // 3. Add timeout to prevent hanging
      String jsonString = await gemini
          .generateKramFlowchart(topic, context, flowchartType: flowchartType)
          .timeout(const Duration(seconds: 45));

      // Clean JSON
      jsonString = _cleanJsonString(jsonString);

      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(roomRef);
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final int currentUses = data['aiUses'] ?? 0;
        final Timestamp? currentReset = data['aiUseReset'] as Timestamp?;
        final now = DateTime.now();
        int newUses;
        Timestamp newReset;

        if (currentReset == null || currentReset.toDate().isBefore(now)) {
          newUses = 1;
          newReset = Timestamp.fromDate(now.add(Duration(hours: 24)));
        } else {
          newUses = currentUses + 1;
          newReset = currentReset;
        }

        if (newUses > _maxAIUses) {
          throw Exception('AI limit reached. Resets at ${newReset.toDate()}.');
        }
        transaction.update(roomRef, {
          'aiUses': newUses,
          'aiUseReset': newReset,
        });
      });

      // Handle Empty/Missing Nodes
      final Map<String, dynamic> flowchart = jsonDecode(jsonString);
      List<dynamic> nodes = flowchart['nodes'] ?? [];
      final List<dynamic> edges = flowchart['edges'] ?? [];

      if (nodes.isEmpty) {
        // FALLBACK: If AI returned empty, create one node
        print("Warning: AI returned 0 nodes. Using fallback.");
        nodes = [
          {
            "id": "fallback_1",
            "text": topic.isNotEmpty ? topic : "New Concept",
            "type": "process",
          },
        ];
      }

      final batch = _firestore.batch();
      final uuid = Uuid();
      final List<KramElementModel> newElements = [];
      final List<KramEdgeModel> newEdges = [];

      // --- Production-Grade Hierarchical Layout (Reingold-Tilford style) ---
      // Step 1: Build graph structures
      final Map<String, List<String>> childrenMap = {};
      final Map<String, List<String>> parentsMap = {};
      final Set<String> allIds = {};
      final Map<String, String> nodeIdMap = {}; // old AI id -> new uuid

      for (var node in nodes) {
        final oldId = node['id']?.toString() ?? uuid.v4();
        final newId = uuid.v4();
        nodeIdMap[oldId] = newId;
        allIds.add(oldId);
        childrenMap[oldId] = [];
        parentsMap[oldId] = [];
      }

      // Deduplicate edges (AI sometimes returns duplicate edges)
      final Set<String> seenEdges = {};
      final List<dynamic> validEdges = [];
      for (var edge in edges) {
        final fromOld = edge['fromId']?.toString() ?? '';
        final toOld = edge['toId']?.toString() ?? '';
        final edgeKey = '$fromOld->$toOld';
        if (fromOld.isNotEmpty &&
            toOld.isNotEmpty &&
            allIds.contains(fromOld) &&
            allIds.contains(toOld) &&
            fromOld != toOld &&
            !seenEdges.contains(edgeKey)) {
          seenEdges.add(edgeKey);
          validEdges.add(edge);
          childrenMap[fromOld]?.add(toOld);
          parentsMap[toOld]?.add(fromOld);
        }
      }

      // Step 2: Find root nodes (no parents)
      List<String> roots = allIds
          .where((id) => (parentsMap[id]?.isEmpty ?? true))
          .toList();

      // Prefer nodes explicitly typed as 'start'
      final startTyped = nodes
          .where((n) => n['type'] == 'start')
          .map((n) => n['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && allIds.contains(id))
          .toList();
      if (startTyped.isNotEmpty) {
        // Put start nodes first
        roots = [
          ...startTyped,
          ...roots.where((id) => !startTyped.contains(id)),
        ];
      }
      if (roots.isEmpty && nodes.isNotEmpty) {
        roots = [nodes[0]['id']?.toString() ?? ''];
      }

      // Step 3: Assign depth levels via BFS (handles DAGs, not just trees)
      final Map<String, int> depthMap = {};
      final bfsQueue = <String>[];
      for (var r in roots) {
        depthMap[r] = 0;
        bfsQueue.add(r);
      }
      while (bfsQueue.isNotEmpty) {
        final cur = bfsQueue.removeAt(0);
        final curDepth = depthMap[cur] ?? 0;
        for (var child in (childrenMap[cur] ?? [])) {
          // Only update if we found a deeper path (longest path for proper layering)
          final existing = depthMap[child];
          if (existing == null || existing < curDepth + 1) {
            depthMap[child] = curDepth + 1;
            bfsQueue.add(child);
          }
        }
      }

      // Assign orphans to extra levels
      int maxDepth = depthMap.isEmpty
          ? 0
          : depthMap.values.reduce((a, b) => a > b ? a : b);
      for (var node in nodes) {
        final id = node['id']?.toString() ?? '';
        if (!depthMap.containsKey(id)) {
          maxDepth++;
          depthMap[id] = maxDepth;
        }
      }

      // Step 4: Group nodes by depth
      final Map<int, List<String>> levelNodes = {};
      for (var entry in depthMap.entries) {
        levelNodes.putIfAbsent(entry.value, () => []).add(entry.key);
      }

      // Step 5: Layout constants
      const double nodeWidth = 220.0;
      const double nodeHeight = 80.0;
      const double horizontalGap = 60.0; // gap between siblings
      const double verticalGap = 140.0; // gap between levels
      const double canvasOriginX = 80.0;
      const double canvasOriginY = 80.0;

      // Step 6: Reingold-Tilford X assignment
      // Compute subtree width for each node (bottom-up)
      final Map<String, double> subtreeWidth = {};

      // Process levels bottom-up
      final sortedLevels = levelNodes.keys.toList()..sort((a, b) => b - a);
      for (var level in sortedLevels) {
        for (var nodeId in (levelNodes[level] ?? [])) {
          final children = childrenMap[nodeId] ?? [];
          if (children.isEmpty) {
            subtreeWidth[nodeId] = nodeWidth;
          } else {
            // Sum of children subtree widths + gaps between them
            double total = children.fold(
              0.0,
              (sum, c) => sum + (subtreeWidth[c] ?? nodeWidth),
            );
            total += (children.length - 1) * horizontalGap;
            // Node must be at least as wide as itself
            subtreeWidth[nodeId] = total < nodeWidth ? nodeWidth : total;
          }
        }
      }

      // Step 7: Assign X positions top-down
      final Map<String, double> xPos = {};
      final Map<String, double> yPos = {};

      // Position roots side by side
      double rootCursor = canvasOriginX;
      for (var r in roots) {
        xPos[r] =
            rootCursor + (subtreeWidth[r] ?? nodeWidth) / 2 - nodeWidth / 2;
        yPos[r] = canvasOriginY;
        rootCursor += (subtreeWidth[r] ?? nodeWidth) + horizontalGap;
      }

      // BFS top-down to assign children positions
      final posQueue = <String>[...roots];
      final Set<String> positioned = {...roots};

      while (posQueue.isNotEmpty) {
        final cur = posQueue.removeAt(0);
        final children = childrenMap[cur] ?? [];
        if (children.isEmpty) continue;

        final curX = xPos[cur] ?? canvasOriginX;
        final curDepth = depthMap[cur] ?? 0;

        // Center children under parent
        double totalChildWidth = children.fold(
          0.0,
          (sum, c) => sum + (subtreeWidth[c] ?? nodeWidth),
        );
        totalChildWidth += (children.length - 1) * horizontalGap;

        double childStartX = curX + nodeWidth / 2 - totalChildWidth / 2;

        for (var child in children) {
          if (!positioned.contains(child)) {
            final childSubtree = subtreeWidth[child] ?? nodeWidth;
            xPos[child] = childStartX + childSubtree / 2 - nodeWidth / 2;
            yPos[child] =
                canvasOriginY +
                (depthMap[child] ?? curDepth + 1) * (nodeHeight + verticalGap);
            positioned.add(child);
            posQueue.add(child);
          }
          childStartX += (subtreeWidth[child] ?? nodeWidth) + horizontalGap;
        }
      }

      // Assign any unpositioned nodes (orphans or cycles)
      double orphanX = canvasOriginX;
      double orphanY =
          canvasOriginY + (maxDepth + 2) * (nodeHeight + verticalGap);
      for (var node in nodes) {
        final id = node['id']?.toString() ?? '';
        if (!xPos.containsKey(id)) {
          xPos[id] = orphanX;
          yPos[id] = orphanY;
          orphanX += nodeWidth + horizontalGap;
        }
      }

      // Step 8: Build node lookup for text/type
      final Map<String, Map<String, dynamic>> nodeDataMap = {};
      for (var node in nodes) {
        nodeDataMap[node['id']?.toString() ?? ''] = node;
      }

      // Step 9: Create Firestore elements with computed positions
      for (var node in nodes) {
        final oldId = node['id']?.toString() ?? '';
        final newId = nodeIdMap[oldId] ?? uuid.v4();
        final nodeData = nodeDataMap[oldId] ?? {};

        final element = KramElementModel(
          id: newId,
          text: nodeData['text'] ?? 'Untitled',
          type: nodeData['type'] ?? 'process',
          authorId: uid,
          x: xPos[oldId] ?? canvasOriginX,
          y: yPos[oldId] ?? canvasOriginY,
          width: nodeWidth,
          height: nodeHeight,
        );

        newElements.add(element);
        batch.set(elementsRef.doc(newId), element.toMap());
      }

      // Create edges with remapped IDs (using deduplicated validEdges)
      for (var edge in validEdges) {
        final oldFromId = edge['fromId']?.toString() ?? '';
        final oldToId = edge['toId']?.toString() ?? '';
        final newFromId = nodeIdMap[oldFromId];
        final newToId = nodeIdMap[oldToId];

        if (newFromId != null && newToId != null) {
          final id = uuid.v4();
          final edgeModel = KramEdgeModel(
            id: id,
            fromId: newFromId,
            toId: newToId,
            fromAnchor: _parseAnchor(edge['fromAnchor']),
            toAnchor: _parseAnchor(edge['toAnchor']),
            authorId: uid,
          );
          newEdges.add(edgeModel);
          batch.set(edgesRef.doc(id), edgeModel.toMap());
        }
      }

      await batch.commit();
      _pushToUndoStack(AddBatchMemento(newElements, newEdges, this));

      await roomRef.update({
        'generationContext': FieldValue.delete(),
        'generationTopic': FieldValue.delete(),
        'flowchartType': FieldValue.delete(),
      });
    } catch (e) {
      print('Error generating AI Kram: $e');
      final errorElement = KramElementModel(
        id: 'error',
        text: 'AI generation failed. Tap to edit.',
        type: 'process',
        authorId: uid,
        x: 100,
        y: 100,
        width: 200,
        height: 80,
      );
      await elementsRef.doc('error').set(errorElement.toMap());
      await roomRef.update({
        'generationContext': FieldValue.delete(),
        'generationTopic': FieldValue.delete(),
        'flowchartType': FieldValue.delete(),
      });
    } finally {
      isGeneratingAI.value = false;
    }
  }

  AnchorSide _parseAnchor(String? anchor) {
    switch (anchor) {
      case 'top':
        return AnchorSide.top;
      case 'right':
        return AnchorSide.right;
      case 'bottom':
        return AnchorSide.bottom;
      case 'left':
        return AnchorSide.left;
      default:
        return AnchorSide.bottom;
    }
  }

  // --- CRUD OPERATIONS ---

  Future<void> addElement(String text, String type, Offset position) async {
    final id = Uuid().v4();
    final element = KramElementModel(
      id: id,
      text: text,
      type: type,
      authorId: uid,
      x: position.dx,
      y: position.dy,
      width: 200,
      height: 80,
    );
    await elementsRef.doc(id).set(element.toMap());
    _pushToUndoStack(AddElementMemento(element, this));
  }

  Future<void> updateElementPosition(
    String id,
    Offset newPosition,
    Offset oldPosition,
  ) async {
    if (selectedElementIds.isEmpty || selectedElementIds.length == 1) {
      await elementsRef.doc(id).update({
        'x': newPosition.dx,
        'y': newPosition.dy,
      });
      _pushToUndoStack(ElementMove(id, newPosition, oldPosition, this));
    }
  }

  Future<void> updateElementText(String id, String newText) async {
    final oldText = elements.firstWhere((el) => el.id == id).text;
    await elementsRef.doc(id).update({'text': newText});
    _pushToUndoStack(ElementTextUpdate(id, newText, oldText, this));
  }

  Future<void> deleteElement(String id) async {
    if (selectedElementIds.isEmpty) {
      selectElement(id);
    }
    await deleteSelectedElements();
  }

  Future<void> deleteSelectedElements() async {
    if (selectedElementIds.isEmpty) return;

    final batch = _firestore.batch();
    final List<KramElementModel> deletedElements = [];
    final List<KramEdgeModel> deletedEdges = [];

    final idsToDelete = Set<String>.from(selectedElementIds);

    for (final id in idsToDelete) {
      final el = elements.firstWhereOrNull((e) => e.id == id);
      if (el != null) {
        deletedElements.add(el);
        batch.delete(elementsRef.doc(id));
      }
    }

    final connectedEdges = edges
        .where(
          (e) => idsToDelete.contains(e.fromId) || idsToDelete.contains(e.toId),
        )
        .toList();
    for (var edge in connectedEdges) {
      deletedEdges.add(edge);
      batch.delete(edgesRef.doc(edge.id));
    }

    await batch.commit();
    _pushToUndoStack(DeleteBatchMemento(deletedElements, deletedEdges, this));
    clearSelection();
  }

  Future<void> addEdge(
    String fromId,
    AnchorSide fromAnchor,
    String toId,
    AnchorSide toAnchor,
  ) async {
    final id = Uuid().v4();
    final edge = KramEdgeModel(
      id: id,
      fromId: fromId,
      toId: toId,
      fromAnchor: fromAnchor,
      toAnchor: toAnchor,
      authorId: uid,
    );
    await edgesRef.doc(id).set(edge.toMap());
    _pushToUndoStack(AddEdgeMemento(edge, this));
  }

  Future<void> deleteEdge(String id) async {
    final edge = edges.firstWhereOrNull((e) => e.id == id);
    if (edge == null) return;

    await edgesRef.doc(id).delete();
    _pushToUndoStack(DeleteEdgeMemento(edge, this));
  }

  // --- NOTE OPERATIONS ---

  Future<void> addNote(String text, Offset position) async {
    final id = Uuid().v4();
    final note = KramNoteModel(
      id: id,
      text: text,
      authorId: uid,
      x: position.dx,
      y: position.dy,
    );
    await notesRef.doc(id).set(note.toMap());
  }

  Future<void> updateNotePosition(String id, Offset newPosition) async {
    await notesRef.doc(id).update({'x': newPosition.dx, 'y': newPosition.dy});
  }

  Future<void> updateNoteText(String id, String text) async {
    await notesRef.doc(id).update({'text': text});
  }

  Future<void> deleteNote(String id) async {
    await notesRef.doc(id).delete();
  }

  // --- COMMENT OPERATIONS ---

  Future<void> addComment(String text, {String? elementId}) async {
    final id = Uuid().v4();
    final comment = KramCommentModel(
      id: id,
      text: text,
      authorId: uid,
      timestamp: DateTime.now(),
      elementId: elementId,
    );
    await commentsRef.doc(id).set(comment.toMap());
  }

  Future<void> deleteComment(String id) async {
    await commentsRef.doc(id).delete();
  }

  Future<void> clearAll() async {
    final batch = _firestore.batch();
    final List<KramElementModel> allElements = List.from(elements);
    final List<KramEdgeModel> allEdges = List.from(edges);

    for (var el in elements) {
      batch.delete(elementsRef.doc(el.id));
    }
    for (var ed in edges) {
      batch.delete(edgesRef.doc(ed.id));
    }
    await batch.commit();
    _pushToUndoStack(DeleteBatchMemento(allElements, allEdges, this));
  }

  // --- COLLABORATOR MANAGEMENT ---

  Future<void> _updateCollaborators(
    String ownerId,
    List<String> collaboratorIds,
  ) async {
    final allIds = {ownerId, ...collaboratorIds};
    final List<CollaboratorModel> loadedCollaborators = [];
    for (final id in allIds) {
      if (id.isEmpty) continue;
      try {
        final userSnap = await _firestore.collection('users').doc(id).get();
        if (userSnap.exists) {
          loadedCollaborators.add(
            CollaboratorModel.fromFirestore(userSnap, isOwner: id == ownerId),
          );
        }
      } catch (e) {
        print('Error loading user $id: $e');
      }
    }
    loadedCollaborators.sort((a, b) {
      if (a.isOwner) return -1;
      if (b.isOwner) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    collaborators.assignAll(loadedCollaborators);
  }

  Future<void> _updateBannedUsers(List<String> bannedUserIds) async {
    final List<CollaboratorModel> loadedBannedUsers = [];
    for (final id in bannedUserIds) {
      if (id.isEmpty) continue;
      try {
        final userSnap = await _firestore.collection('users').doc(id).get();
        if (userSnap.exists) {
          loadedBannedUsers.add(
            CollaboratorModel.fromFirestore(userSnap, isOwner: false),
          );
        }
      } catch (e) {
        print('Error loading banned user $id: $e');
      }
    }
    loadedBannedUsers.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    bannedUsers.assignAll(loadedBannedUsers);
  }

  Future<void> removeCollaborator(String userId) async {
    if (!isOwner.value)
      throw Exception('Only the owner can remove collaborators.');
    final owner = (await roomRef.get()).get('owner');
    if (userId == owner) throw Exception('Cannot remove the owner.');
    try {
      await roomRef.update({
        'collaborators': FieldValue.arrayRemove([userId]),
        'bannedUsers': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('Failed to remove collaborator.');
    }
  }

  Future<void> unblockCollaborator(String userId) async {
    if (!isOwner.value)
      throw Exception('Only the owner can manage the ban list.');
    try {
      await roomRef.update({
        'bannedUsers': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      throw Exception('Failed to unblock collaborator.');
    }
  }

  // --- ANALYTICS & EXPORT ---
  int getElementCount() => elements.length;
  int getEdgeCount() => edges.length;
  int getUniqueAuthors() => elements.map((e) => e.authorId).toSet().length;

  List<KramElementModel> searchElements(String query) {
    final lowerQuery = query.toLowerCase();
    return elements
        .where((n) => n.text.toLowerCase().contains(lowerQuery))
        .toList();
  }

  String exportAsText() {
    if (elements.isEmpty) return 'No elements to export';

    final buffer = StringBuffer();
    buffer.writeln('Kram Export: ${roomTitle.value}');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Total Elements: ${elements.length}');
    buffer.writeln('Total Edges: ${edges.length}');
    buffer.writeln('\n${'=' * 50}\n');

    final elementMap = {for (var el in elements) el.id: el};
    final visited = <String>{};

    final startNodes = elements.where((el) => el.type == 'start').toList();
    if (startNodes.isEmpty) {
      final allToIds = edges.map((e) => e.toId).toSet();
      startNodes.addAll(elements.where((el) => !allToIds.contains(el.id)));
    }

    if (startNodes.isEmpty && elements.isNotEmpty) {
      startNodes.add(elements.first);
    }

    for (var node in startNodes) {
      _exportNodeRecursive(node, buffer, 0, elementMap, visited);
    }

    return buffer.toString();
  }

  void _exportNodeRecursive(
    KramElementModel node,
    StringBuffer buffer,
    int level,
    Map<String, KramElementModel> elementMap,
    Set<String> visited,
  ) {
    if (visited.contains(node.id)) return;
    visited.add(node.id);

    final indent = '  ' * level;
    buffer.writeln('$indent[${node.type.capitalizeFirst}] ${node.text}');

    final outgoingEdges = edges.where((e) => e.fromId == node.id).toList();
    for (var edge in outgoingEdges) {
      final childNode = elementMap[edge.toId];
      if (childNode != null) {
        _exportNodeRecursive(childNode, buffer, level + 1, elementMap, visited);
      }
    }
  }
}

// --- UNDO/REDO MEMENTO IMPLEMENTATIONS ---

// --- ELEMENT MEMENTOS ---

class AddElementMemento implements IKramMemento {
  final KramElementModel element;
  final KramController ctrl;
  AddElementMemento(this.element, this.ctrl);

  @override
  void execute() => ctrl.elementsRef.doc(element.id).set(element.toMap());
  @override
  void unexecute() => ctrl.elementsRef.doc(element.id).delete();
}

class DeleteElementMemento implements IKramMemento {
  final KramElementModel element;
  final KramController ctrl;
  DeleteElementMemento(this.element, this.ctrl);

  @override
  void execute() => ctrl.elementsRef.doc(element.id).delete();
  @override
  void unexecute() => ctrl.elementsRef.doc(element.id).set(element.toMap());
}

class ElementMove implements IKramMemento {
  final String id;
  final Offset newPos;
  final Offset oldPos;
  final KramController ctrl;
  ElementMove(this.id, this.newPos, this.oldPos, this.ctrl);

  @override
  void execute() =>
      ctrl.elementsRef.doc(id).update({'x': newPos.dx, 'y': newPos.dy});
  @override
  void unexecute() =>
      ctrl.elementsRef.doc(id).update({'x': oldPos.dx, 'y': oldPos.dy});
}

class ElementTextUpdate implements IKramMemento {
  final String id;
  final String newText;
  final String oldText;
  final KramController ctrl;
  ElementTextUpdate(this.id, this.newText, this.oldText, this.ctrl);

  @override
  void execute() => ctrl.elementsRef.doc(id).update({'text': newText});
  @override
  void unexecute() => ctrl.elementsRef.doc(id).update({'text': oldText});
}

// --- EDGE MEMENTOS ---

class AddEdgeMemento implements IKramMemento {
  final KramEdgeModel edge;
  final KramController ctrl;
  AddEdgeMemento(this.edge, this.ctrl);

  @override
  void execute() => ctrl.edgesRef.doc(edge.id).set(edge.toMap());
  @override
  void unexecute() => ctrl.edgesRef.doc(edge.id).delete();
}

class DeleteEdgeMemento implements IKramMemento {
  final KramEdgeModel edge;
  final KramController ctrl;
  DeleteEdgeMemento(this.edge, this.ctrl);

  @override
  void execute() => ctrl.edgesRef.doc(edge.id).delete();
  @override
  void unexecute() => ctrl.edgesRef.doc(edge.id).set(edge.toMap());
}

// --- BATCH MEMENTOS ---

class AddBatchMemento implements IKramMemento {
  final List<KramElementModel> elements;
  final List<KramEdgeModel> edges;
  final KramController ctrl;
  AddBatchMemento(this.elements, this.edges, this.ctrl);

  @override
  void execute() {
    final batch = ctrl._firestore.batch();
    for (var el in elements) batch.set(ctrl.elementsRef.doc(el.id), el.toMap());
    for (var ed in edges) batch.set(ctrl.edgesRef.doc(ed.id), ed.toMap());
    batch.commit();
  }

  @override
  void unexecute() {
    final batch = ctrl._firestore.batch();
    for (var el in elements) batch.delete(ctrl.elementsRef.doc(el.id));
    for (var ed in edges) batch.delete(ctrl.edgesRef.doc(ed.id));
    batch.commit();
  }
}

class DeleteBatchMemento implements IKramMemento {
  final List<KramElementModel> elements;
  final List<KramEdgeModel> edges;
  final KramController ctrl;
  DeleteBatchMemento(this.elements, this.edges, this.ctrl);

  @override
  void execute() {
    final batch = ctrl._firestore.batch();
    for (var el in elements) batch.delete(ctrl.elementsRef.doc(el.id));
    for (var ed in edges) batch.delete(ctrl.edgesRef.doc(ed.id));
    batch.commit();
  }

  @override
  void unexecute() {
    final batch = ctrl._firestore.batch();
    for (var el in elements) batch.set(ctrl.elementsRef.doc(el.id), el.toMap());
    for (var ed in edges) batch.set(ctrl.edgesRef.doc(ed.id), ed.toMap());
    batch.commit();
  }
}

class BatchMoveMemento implements IKramMemento {
  final List<ElementMove> moves;
  final KramController ctrl;
  BatchMoveMemento(this.moves, this.ctrl);

  @override
  void execute() {
    final batch = ctrl._firestore.batch();
    for (var move in moves) {
      batch.update(ctrl.elementsRef.doc(move.id), {
        'x': move.newPos.dx,
        'y': move.newPos.dy,
      });
    }
    batch.commit();
  }

  @override
  void unexecute() {
    final batch = ctrl._firestore.batch();
    for (var move in moves) {
      batch.update(ctrl.elementsRef.doc(move.id), {
        'x': move.oldPos.dx,
        'y': move.oldPos.dy,
      });
    }
    batch.commit();
  }
}
