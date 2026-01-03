// FILE: lib/controllers/VyuhaController.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:vyuha/controllers/AuthController.dart';
import 'dart:math';
import 'dart:async'; // Added for TimeoutException

import 'package:vyuha/models/NodeModel.dart';
import 'package:vyuha/models/CollaboratorModel.dart';
import 'package:vyuha/services/GeminiService.dart';

class VyuhaController extends GetxController {
  final String roomId;
  VyuhaController(this.roomId);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxList<NodeModel> nodes = <NodeModel>[].obs;
  final RxString roomTitle = 'Untitled'.obs;
  final RxString passkey = ''.obs;
  final RxBool isOwner = false.obs;
  
  // State list to hold full collaborator details
  final RxList<CollaboratorModel> collaborators = <CollaboratorModel>[].obs;

  // State list for banned user details
  final RxList<CollaboratorModel> bannedUsers = <CollaboratorModel>[].obs;

  // State for AI Limits
  final RxInt aiUsesRemaining = 15.obs;
  final Rx<DateTime?> aiUseResetTime = Rx<DateTime?>(null);
  
  // UI State for AI operations
  final RxBool isPerformingAI = false.obs;
  
  static const int _maxAIUses = 15;

  // REMOVED: final gemini = GeminiService(); 
  // We will instantiate this locally to prevent history accumulation.
  
  final uid = Get.find<AuthController>().uid;
  late final CollectionReference roomNodesRef;
  late final DocumentReference roomRef;

  @override
  void onInit() {
    super.onInit();
    roomRef = _firestore.collection('rooms').doc(roomId);
    roomNodesRef = roomRef.collection('nodes');
    _listenNodes();
    _loadRoomInfo();
  }

  void _loadRoomInfo() {
    roomRef.snapshots().listen((snap) async {
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>? ?? {};

        roomTitle.value = data['title'] ?? 'Untitled';
        passkey.value = data['passkey'] ?? '';
        final owner = data['owner'] ?? '';
        isOwner.value = owner == uid;

        // --- Collaborator Logic ---
        final collaboratorIds = List<String>.from(data['collaborators'] ?? []);
        await _updateCollaborators(owner, collaboratorIds);
        
        // --- Banned User Logic ---
        final bannedUserIds = List<String>.from(data['bannedUsers'] ?? []);
        await _updateBannedUsers(bannedUserIds);

        // --- AI Limit Logic ---
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
      }
    });
  }

  Future<void> _updateCollaborators(String ownerId, List<String> collaboratorIds) async {
    final allIds = {ownerId, ...collaboratorIds};
    final List<CollaboratorModel> loadedCollaborators = [];

    for (final id in allIds) {
      if (id.isEmpty) continue;
      try {
        final userSnap = await _firestore.collection('users').doc(id).get();
        if (userSnap.exists) {
          loadedCollaborators.add(
            CollaboratorModel.fromFirestore(userSnap, isOwner: id == ownerId)
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
            CollaboratorModel.fromFirestore(userSnap, isOwner: false)
          );
        }
      } catch (e) {
        print('Error loading banned user $id: $e');
      }
    }

    loadedBannedUsers.sort((a, b) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    bannedUsers.assignAll(loadedBannedUsers);
  }

  void _listenNodes() {
    roomNodesRef.snapshots().listen((snap) {
      final list = snap.docs
          .map((d) => NodeModel.fromMap({
                'id': d.id,
                'text': d['text'] ?? '',
                'parentId': d['parentId'] ?? '',
                'authorId': d['authorId'] ?? ''
              }))
          .toList();
      nodes.assignAll(list);
    });
  }

  Future<void> addNode(String text, {String parentId = ''}) async {
    final id = Uuid().v4();
    final nm = NodeModel(id: id, text: text, parentId: parentId, authorId: uid);
    await roomNodesRef.doc(id).set(nm.toMap());
  }

  Future<void> updateNode(String id, String newText) async {
    await roomNodesRef.doc(id).update({'text': newText});
  }

  Future<void> deleteNode(String id) async {
    final children = nodes.where((n) => n.parentId == id).toList();
    for (var child in children) {
      await deleteNode(child.id);
    }
    await roomNodesRef.doc(id).delete();
  }

  Future<void> clearAllNodes() async {
    final batch = _firestore.batch();
    for (var node in nodes) {
      batch.delete(roomNodesRef.doc(node.id));
    }
    await batch.commit();
  }

  Future<void> removeCollaborator(String userId) async {
    if (!isOwner.value) {
      throw Exception('Only the owner can remove collaborators.');
    }
    final owner = (await roomRef.get()).get('owner');
    if (userId == owner) {
       throw Exception('Cannot remove the owner.');
    }

    try {
      await roomRef.update({
        'collaborators': FieldValue.arrayRemove([userId]),
        'bannedUsers': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      print('Error removing collaborator: $e');
      throw Exception('Failed to remove collaborator.');
    }
  }

  Future<void> unblockCollaborator(String userId) async {
    if (!isOwner.value) {
      throw Exception('Only the owner can manage the ban list.');
    }

    try {
      await roomRef.update({
        'bannedUsers': FieldValue.arrayRemove([userId])
      });
    } catch (e) {
      print('Error unblocking collaborator: $e');
      throw Exception('Failed to unblock collaborator.');
    }
  }

  Future<void> expandWithAI({
    required String topic,
    int count = 5,
    String? parentId,
  }) async {
    // 1. Check for re-entry or exhaustion
    if (isPerformingAI.value) return; 
    
    if (aiUsesRemaining.value <= 0) {
      String resetMsg = 'Resets soon.';
      if (aiUseResetTime.value != null) {
        final hours = aiUseResetTime.value!.difference(DateTime.now()).inHours;
        resetMsg = 'Resets in ~${hours}h.';
      }
      throw Exception('AI limit reached. $resetMsg');
    }

    isPerformingAI.value = true;

    try {
      // 2. Instantiate SERVICE LOCALLY
      // This ensures we get a fresh session and DO NOT send previous history.
      // This prevents "Token Exhaustion" caused by growing context windows.
      final gemini = GeminiService(); 

      // 3. Add Timeout
      // Prevents "infinite hang" if the service loops or network stalls.
      final ideas = await gemini.generateIdeas(topic, count: count)
          .timeout(const Duration(seconds: 15));

      if (ideas.isEmpty) {
        return; 
      }

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
          throw Exception('AI limit reached during transaction.');
        }

        transaction.update(roomRef, {
          'aiUses': newUses,
          'aiUseReset': newReset,
        });
      });
      
      for (var idea in ideas) {
        await addNode(idea, parentId: parentId ?? 'root');
      }

    } catch (e) {
      print('Error in expandWithAI: $e');
      if (e is TimeoutException) {
         throw Exception('AI request timed out. Please try again.');
      }
      if (e.toString().contains('AI limit reached')) {
        rethrow;
      }
      throw Exception('Failed to generate AI ideas: $e');
    } finally {
      isPerformingAI.value = false;
    }
  }

  Future<String> explainNodeWithAI(String topic) async {
     try {
       // Instantiate locally for statelessness
       final gemini = GeminiService();
       return await gemini.generateExplanation(topic)
           .timeout(const Duration(seconds: 20));
     } catch (e) {
       print('Error in explainNodeWithAI: $e');
       rethrow;
     }
  }

  String _generatePasskey() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  Future<void> initializePasskey() async {
    if (passkey.value.isEmpty) {
      final newPasskey = _generatePasskey();
      await roomRef.update({'passkey': newPasskey});
      passkey.value = newPasskey;
    }
  }

  Future<String> joinVyuhaWithPasskey(String inputPasskey) async {
    try {
      final snap = await _firestore
          .collection('rooms')
          .where('passkey', isEqualTo: inputPasskey)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        throw Exception('Not Found');
      }

      final roomDoc = snap.docs.first;
      final roomId = roomDoc.id;
      final owner = roomDoc.get('owner') ?? '';
      final collaborators = List<String>.from(roomDoc.get('collaborators') ?? []);
      final bannedUsers = List<String>.from(roomDoc.get('bannedUsers') ?? []);

      if (owner == uid) {
        throw Exception('Already Owner');
      }

      if (collaborators.contains(uid)) {
        throw Exception('Already Joined');
      }

      if (bannedUsers.contains(uid)) {
        throw Exception('Banned');
      }

      await _firestore.collection('rooms').doc(roomId).update({
        'collaborators': FieldValue.arrayUnion([uid])
      });

      return roomId;
      
    } catch (e) {
      print('Error joining Vyuha: $e');
      if (e is Exception && e.toString().contains('Not Found')) {
        throw Exception('No Vyuha found with this passkey');
      }
      if (e is Exception && e.toString().contains('Already Owner')) {
        throw Exception('You are the owner of this Vyuha');
      }
      if (e is Exception && e.toString().contains('Already Joined')) {
        throw Exception('You are already a collaborator');
      }
      if (e is Exception && e.toString().contains('Banned')) {
        throw Exception('You are not allowed to join this Vyuha');
      }
      if (e.toString().contains('requires an index')) {
           throw Exception('Database setup incomplete. Please contact support.');
      }
      throw Exception('Failed to join Vyuha');
    }
  }

  Future<bool> hasAccess() async {
    try {
      final snap = await roomRef.get();
      if (!snap.exists) return false;

      final owner = snap.get('owner') ?? '';
      final collaborators = List<String>.from(snap.get('collaborators') ?? []);
      
      return owner == uid || collaborators.contains(uid);
    } catch (e) {
      print('Error checking access: $e');
      return false;
    }
  }

  int getDepth() {
    if (nodes.isEmpty) return 0;
    int maxDepth = 0;
    for (var node in nodes) {
      final depth = getNodeDepth(node.id);
      if (depth > maxDepth) maxDepth = depth;
    }
    return maxDepth + 1;
  }

  int getNodeDepth(String nodeId) {
    int depth = 0;
    String? currentId = nodeId;
    final visited = <String>{};
    
    while (currentId != null && currentId.isNotEmpty && currentId != 'root') {
      if (visited.contains(currentId)) break;
      visited.add(currentId);
      
      final node = nodes.firstWhereOrNull((n) => n.id == currentId);
      if (node == null) break;
      currentId = node.parentId;
      depth++;
    }
    return depth;
  }

  int getChildrenCount(String nodeId) {
    return nodes.where((n) => n.parentId == nodeId).length;
  }

  int getUniqueAuthors() {
    final authors = nodes.map((n) => n.authorId).toSet();
    return authors.length;
  }

  List<NodeModel> searchNodes(String query) {
    final lowerQuery = query.toLowerCase();
    return nodes
        .where((n) => n.text.toLowerCase().contains(lowerQuery))
        .toList();
  }

  String exportAsText() {
    if (nodes.isEmpty) return 'No nodes to export';
    
    final buffer = StringBuffer();
    buffer.writeln('Vyuha Export: ${roomTitle.value}');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Total Ideas: ${nodes.length}');
    buffer.writeln('\n${'=' * 50}\n');
    
    final rootNodes = nodes.where((n) => n.parentId.isEmpty || n.parentId == 'root').toList();
    for (var node in rootNodes) {
      _exportNodeRecursive(node, buffer, 0);
    }
    
    return buffer.toString();
  }

  void _exportNodeRecursive(NodeModel node, StringBuffer buffer, int level) {
    final indent = '  ' * level;
    buffer.writeln('$indent• ${node.text}');
    
    final children = nodes.where((n) => n.parentId == node.id).toList();
    for (var child in children) {
      _exportNodeRecursive(child, buffer, level + 1);
    }
  }

  List<NodeModel> getChildren(String parentId) {
    return nodes.where((n) => n.parentId == parentId).toList();
  }

  List<NodeModel> getRootNodes() {
    return nodes.where((n) => n.parentId.isEmpty || n.parentId == 'root').toList();
  }
}