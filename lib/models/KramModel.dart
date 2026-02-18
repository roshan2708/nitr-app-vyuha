// FILE: lib/models/KramModel.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vyuha/controllers/KramController.dart'; // Import for AnchorSide

class KramElementModel {
  final String id;
  final String text;
  final String type; // e.g., 'start', 'process', 'decision', 'end'
  final String authorId;
  final double x;
  final double y;
  final double width; // ADDED: For element resizing
  final double height; // ADDED: For element resizing

  KramElementModel({
    required this.id,
    required this.text,
    required this.type,
    required this.authorId,
    required this.x,
    required this.y,
    this.width = 200.0, // ADDED: Default value
    this.height = 80.0, // ADDED: Default value
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'type': type,
      'authorId': authorId,
      'x': x,
      'y': y,
      'width': width, // ADDED
      'height': height, // ADDED
    };
  }

  factory KramElementModel.fromMap(Map<String, dynamic> map) {
    return KramElementModel(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'process',
      authorId: map['authorId'] ?? '',
      x: (map['x'] ?? 0.0).toDouble(),
      y: (map['y'] ?? 0.0).toDouble(),
      width: (map['width'] ?? 200.0).toDouble(), // ADDED
      height: (map['height'] ?? 80.0).toDouble(), // ADDED
    );
  }

  // ADDED: copyWith method for optimistic UI updates and undo/redo
  KramElementModel copyWith({
    String? id,
    String? text,
    String? type,
    String? authorId,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return KramElementModel(
      id: id ?? this.id,
      text: text ?? this.text,
      type: type ?? this.type,
      authorId: authorId ?? this.authorId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

class KramEdgeModel {
  final String id;
  final String fromId;
  final String toId;
  final AnchorSide fromAnchor; // ADDED: For specific connection points
  final AnchorSide toAnchor; // ADDED: For specific connection points
  final String authorId;

  KramEdgeModel({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.fromAnchor, // ADDED
    required this.toAnchor, // ADDED
    required this.authorId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromId': fromId,
      'toId': toId,
      'fromAnchor': fromAnchor
          .toString()
          .split('.')
          .last, // ADDED: Store as string
      'toAnchor': toAnchor.toString().split('.').last, // ADDED: Store as string
      'authorId': authorId,
    };
  }

  factory KramEdgeModel.fromMap(Map<String, dynamic> map) {
    return KramEdgeModel(
      id: map['id'] ?? '',
      fromId: map['fromId'] ?? '',
      toId: map['toId'] ?? '',
      fromAnchor: _parseAnchor(map['fromAnchor']), // ADDED
      toAnchor: _parseAnchor(map['toAnchor']), // ADDED
      authorId: map['authorId'] ?? '',
    );
  }

  // ADDED: copyWith method for undo/redo
  KramEdgeModel copyWith({
    String? id,
    String? fromId,
    String? toId,
    AnchorSide? fromAnchor,
    AnchorSide? toAnchor,
    String? authorId,
  }) {
    return KramEdgeModel(
      id: id ?? this.id,
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      fromAnchor: fromAnchor ?? this.fromAnchor,
      toAnchor: toAnchor ?? this.toAnchor,
      authorId: authorId ?? this.authorId,
    );
  }
}

// ADDED: Helper function to parse anchor string from Firestore
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
      return AnchorSide.bottom; // Default
  }
}

// POSIT: Added KramNoteModel for sticky notes on the canvas
class KramNoteModel {
  final String id;
  final String text;
  final String authorId;
  final double x;
  final double y;
  final double width;
  final double height;
  final String color; // Hex color string

  KramNoteModel({
    required this.id,
    required this.text,
    required this.authorId,
    required this.x,
    required this.y,
    this.width = 200.0,
    this.height = 200.0,
    this.color = '#FFF9C4', // Default yellow sticky note
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'authorId': authorId,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'color': color,
    };
  }

  factory KramNoteModel.fromMap(Map<String, dynamic> map) {
    return KramNoteModel(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      authorId: map['authorId'] ?? '',
      x: (map['x'] ?? 0.0).toDouble(),
      y: (map['y'] ?? 0.0).toDouble(),
      width: (map['width'] ?? 200.0).toDouble(),
      height: (map['height'] ?? 200.0).toDouble(),
      color: map['color'] ?? '#FFF9C4',
    );
  }

  KramNoteModel copyWith({
    String? id,
    String? text,
    String? authorId,
    double? x,
    double? y,
    double? width,
    double? height,
    String? color,
  }) {
    return KramNoteModel(
      id: id ?? this.id,
      text: text ?? this.text,
      authorId: authorId ?? this.authorId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      color: color ?? this.color,
    );
  }
}

// POSIT: Added KramCommentModel for discussions
class KramCommentModel {
  final String id;
  final String text;
  final String authorId;
  final DateTime timestamp;
  final String? elementId; // Optional: link to a specific node

  KramCommentModel({
    required this.id,
    required this.text,
    required this.authorId,
    required this.timestamp,
    this.elementId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'authorId': authorId,
      'timestamp': Timestamp.fromDate(timestamp),
      if (elementId != null) 'elementId': elementId,
    };
  }

  factory KramCommentModel.fromMap(Map<String, dynamic> map) {
    return KramCommentModel(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      authorId: map['authorId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      elementId: map['elementId'],
    );
  }
}
