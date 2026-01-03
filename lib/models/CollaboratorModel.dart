import 'package:cloud_firestore/cloud_firestore.dart';

class CollaboratorModel {
  final String id;
  final String name;
  final String username;
  final bool isOwner;

  CollaboratorModel({
    required this.id,
    required this.name,
    required this.username,
    this.isOwner = false,
  });

  /// Creates a CollaboratorModel from a Firestore user document.
  ///
  /// Assumes your 'users' collection documents have 'name' and 'username' fields.
  factory CollaboratorModel.fromFirestore(DocumentSnapshot snap, {bool isOwner = false}) {
    final data = snap.data() as Map<String, dynamic>;
    return CollaboratorModel(
      id: snap.id,
      name: data['name'] ?? 'Unknown Name',
      username: data['username'] ?? 'unknown',
      isOwner: isOwner,
    );
  }
}