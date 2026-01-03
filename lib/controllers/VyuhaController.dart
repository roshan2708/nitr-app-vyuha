import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:vyuha/controllers/AuthController.dart';
import 'dart:math';

import 'package:vyuha/models/NodeModel.dart';
// Import the new collaborator model
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

  // --- NEW: State list for banned user details ---
  final RxList<CollaboratorModel> bannedUsers = <CollaboratorModel>[].obs;

  // State for AI Limits
  final RxInt aiUsesRemaining = 15.obs;
  final Rx<DateTime?> aiUseResetTime = Rx<DateTime?>(null);
  static const int _maxAIUses = 15;

  final gemini = GeminiService();
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

  // MODIFIED: This method now also loads collaborator details, banned user details, and AI limits
  void _loadRoomInfo() {
    roomRef.snapshots().listen((snap) async { // Make async
      if (snap.exists) {
        // Safer data access
        final data = snap.data() as Map<String, dynamic>? ?? {};

        roomTitle.value = data['title'] ?? 'Untitled';
        passkey.value = data['passkey'] ?? '';
        final owner = data['owner'] ?? '';
        isOwner.value = owner == uid;

        // --- Collaborator Logic ---
        final collaboratorIds = List<String>.from(data['collaborators'] ?? []);
        await _updateCollaborators(owner, collaboratorIds);
        
        // --- NEW: Banned User Logic ---
        final bannedUserIds = List<String>.from(data['bannedUsers'] ?? []);
        await _updateBannedUsers(bannedUserIds); // Call new helper

        // --- AI Limit Logic ---
        final int aiUses = data['aiUses'] ?? 0;
        final Timestamp? aiUseReset = data['aiUseReset'] as Timestamp?;
        final now = DateTime.now();

        if (aiUseReset == null || aiUseReset.toDate().isBefore(now)) {
          // Reset time is in the past, so reset the counter
          aiUsesRemaining.value = _maxAIUses;
          aiUseResetTime.value = null; 
          // If uses were > 0, we should reset them in Firestore.
          // Do this only if aiUses is not already 0 to avoid writes.
          if (aiUses > 0) {
             roomRef.update({'aiUses': 0, 'aiUseReset': null});
          }
        } else {
          // Reset time is in the future
          aiUsesRemaining.value = (_maxAIUses - aiUses).clamp(0, _maxAIUses);
          aiUseResetTime.value = aiUseReset.toDate();
        }

      }
    });
  }

  // Helper method to fetch user details from UIDs
  Future<void> _updateCollaborators(String ownerId, List<String> collaboratorIds) async {
    // Use a Set to automatically handle duplicates (e.g., if owner is also in list)
    final allIds = {ownerId, ...collaboratorIds};
    
    final List<CollaboratorModel> loadedCollaborators = [];

    // Fetch each user's document
    for (final id in allIds) {
      if (id.isEmpty) continue;
      try {
        final userSnap = await _firestore.collection('users').doc(id).get();
        if (userSnap.exists) {
          // Create model, marking the owner
          loadedCollaborators.add(
            CollaboratorModel.fromFirestore(userSnap, isOwner: id == ownerId)
          );
        }
      } catch (e) {
        print('Error loading user $id: $e');
      }
    }

    // Sort the list to show the Owner first, then alphabetically
    loadedCollaborators.sort((a, b) {
      if (a.isOwner) return -1;
      if (b.isOwner) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // Update the observable list
    collaborators.assignAll(loadedCollaborators);
  }

  // --- NEW: Helper method to fetch banned user details ---
  Future<void> _updateBannedUsers(List<String> bannedUserIds) async {
    final List<CollaboratorModel> loadedBannedUsers = [];
    
    for (final id in bannedUserIds) {
      if (id.isEmpty) continue;
      try {
        final userSnap = await _firestore.collection('users').doc(id).get();
        if (userSnap.exists) {
          // Create model, they are never the owner
          loadedBannedUsers.add(
            CollaboratorModel.fromFirestore(userSnap, isOwner: false)
          );
        }
      } catch (e) {
        print('Error loading banned user $id: $e');
      }
    }

    // Sort the list alphabetically
    loadedBannedUsers.sort((a, b) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // Update the observable list
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
    // Delete this node and all its children recursively
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

  // UPDATED: Method to remove a collaborator and add them to the ban list
  Future<void> removeCollaborator(String userId) async {
    // This check is important! Only the owner can remove people.
    if (!isOwner.value) {
      throw Exception('Only the owner can remove collaborators.');
    }
    // Prevent the owner from being removed from the collaborator list
    final owner = (await roomRef.get()).get('owner');
    if (userId == owner) {
       throw Exception('Cannot remove the owner.');
    }

    try {
      // Use FieldValue.arrayRemove to safely remove the UID from the list
      // AND add them to the bannedUsers list to prevent re-joining.
      await roomRef.update({
        'collaborators': FieldValue.arrayRemove([userId]),
        'bannedUsers': FieldValue.arrayUnion([userId]) // ADDED THIS LINE
      });
      // The _loadRoomInfo listener will automatically see this change
      // and call _updateCollaborators, which updates the UI.
    } catch (e) {
      print('Error removing collaborator: $e');
      throw Exception('Failed to remove collaborator.');
    }
  }

  // --- NEW: Method to unban a user ---
  Future<void> unblockCollaborator(String userId) async {
    // Only the owner can unblock people.
    if (!isOwner.value) {
      throw Exception('Only the owner can manage the ban list.');
    }

    try {
      // Use FieldValue.arrayRemove to safely remove the UID from the banned list
      await roomRef.update({
        'bannedUsers': FieldValue.arrayRemove([userId])
      });
      // The _loadRoomInfo listener will automatically see this change
      // and call _updateBannedUsers, which updates the UI.
      // Note: This does NOT re-add them as a collaborator.
      // It just allows them to join again with the passkey.
    } catch (e) {
      print('Error unblocking collaborator: $e');
      throw Exception('Failed to unblock collaborator.');
    }
  }

  // MODIFIED: This method now checks limits and runs a transaction on success
  Future<void> expandWithAI({
    required String topic,
    int count = 5,
    String? parentId,
  }) async {
    // 1. Check local state first for a fast failure
    if (aiUsesRemaining.value <= 0) {
      String resetMsg = 'Resets soon.';
      if (aiUseResetTime.value != null) {
        final hours = aiUseResetTime.value!.difference(DateTime.now()).inHours;
        resetMsg = 'Resets in ~${hours}h.';
      }
      throw Exception('AI limit reached. $resetMsg');
    }

    try {
      // 2. Call the external service
      final ideas = await gemini.generateIdeas(topic, count: count);
      if (ideas.isEmpty) {
        return; // Nothing to add
      }

      // 3. Run a transaction to update the count atomically
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(roomRef);
        final data = snap.data() as Map<String, dynamic>? ?? {};

        final int currentUses = data['aiUses'] ?? 0;
        final Timestamp? currentReset = data['aiUseReset'] as Timestamp?;
        final now = DateTime.now();

        int newUses;
        Timestamp newReset;

        if (currentReset == null || currentReset.toDate().isBefore(now)) {
          // Timer is expired or not set, so this is the first use of the new period
          newUses = 1;
          newReset = Timestamp.fromDate(now.add(Duration(hours: 24)));
        } else {
          // Timer is active, increment uses
          newUses = currentUses + 1;
          newReset = currentReset; // Keep existing reset time
        }

        // Final check inside transaction to ensure we don't go over
        if (newUses > _maxAIUses) {
          throw Exception('AI limit reached. Resets at ${newReset.toDate()}.');
        }

        // Update the room document with new usage stats
        transaction.update(roomRef, {
          'aiUses': newUses,
          'aiUseReset': newReset,
        });
      });
      
      // 4. If transaction and API call were successful, add the nodes
      for (var idea in ideas) {
        await addNode(idea, parentId: parentId ?? 'root');
      }

    } catch (e) {
      print('Error in expandWithAI: $e');
      // Re-throw the exception to be caught by the UI
      if (e.toString().contains('AI limit reached')) {
        rethrow;
      }
      throw Exception('Failed to generate AI ideas');
    }
  }

  // Generate a 6-digit passkey
  String _generatePasskey() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  // Initialize passkey for a new Vyuha (called by owner)
  Future<void> initializePasskey() async {
    if (passkey.value.isEmpty) {
      final newPasskey = _generatePasskey();
      await roomRef.update({'passkey': newPasskey});
      passkey.value = newPasskey;
    }
  }

  // UPDATED: This method now checks the ban list before joining
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
      
      // NEW: Get the list of banned UIDs
      final bannedUsers = List<String>.from(roomDoc.get('bannedUsers') ?? []);

      // Check if user is already the owner
      if (owner == uid) {
        throw Exception('Already Owner');
      }

      // Check if user is already a collaborator
      if (collaborators.contains(uid)) {
        throw Exception('Already Joined');
      }

      // NEW: Check if the user is in the ban list
      if (bannedUsers.contains(uid)) {
        throw Exception('Banned');
      }

      // If not, add user to collaborators
      await _firestore.collection('rooms').doc(roomId).update({
        'collaborators': FieldValue.arrayUnion([uid])
      });

      return roomId; // Return the room ID on success
      
    } catch (e) {
      print('Error joining Vyuha: $e');
      // Re-throw the error to be handled by the UI
      if (e is Exception && e.toString().contains('Not Found')) {
        throw Exception('No Vyuha found with this passkey');
      }
      if (e is Exception && e.toString().contains('Already Owner')) {
        throw Exception('You are the owner of this Vyuha');
      }
      if (e is Exception && e.toString().contains('Already Joined')) {
        throw Exception('You are already a collaborator');
      }
      // NEW: Handle banned user
      if (e is Exception && e.toString().contains('Banned')) {
        throw Exception('You are not allowed to join this Vyuha');
      }
      // This is the most likely error: Missing Firestore Index
      if (e.toString().contains('requires an index')) {
           throw Exception('Database setup incomplete. Please contact support.');
      }
      throw Exception('Failed to join Vyuha');
    }
  }
  // Check if user has access to this Vyuha
  Future<bool> hasAccess() async {
    try {
      final snap = await roomRef.get();
      if (!snap.exists) return false;

      final owner = snap.get('owner') ?? '';
      final collaborators = List<String>.from(snap.get('collaborators') ?? []);
      
      // Note: We don't need to check the ban list here, because if a user
      // is banned, they are also removed from the 'collaborators' list.
      // This check remains correct.
      return owner == uid || collaborators.contains(uid);
    } catch (e) {
      print('Error checking access: $e');
      return false;
    }
  }

  // Analytics methods
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
    // NEW: We should use the collaborators list as the source of truth
    // for unique authors *present* in the room, not just who has added a node.
    // But the original function counted nodes, so let's stick to that.
    // However, `collaborators.length` is a better metric for "people in room".
    // The user's original function was `getUniqueAuthors()`, so we'll keep its logic.
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
    
    // Export as hierarchical tree
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

  // Get nodes by parent for tree building
  List<NodeModel> getChildren(String parentId) {
    return nodes.where((n) => n.parentId == parentId).toList();
  }

  List<NodeModel> getRootNodes() {
    return nodes.where((n) => n.parentId.isEmpty || n.parentId == 'root').toList();
  }
}