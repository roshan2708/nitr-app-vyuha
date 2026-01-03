
import 'package:flutter/material.dart';

// --- Flowchart Models ---

enum FlowShapeType { rectangle, oval, diamond }

class KramFlowElement {
  final String id;
  String text;
  double x;
  double y;
  final FlowShapeType type;
  // List of IDs this element connects TO
  List<String> connections;

  KramFlowElement({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.type,
    this.connections = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'x': x,
      'y': y,
      'type': type.index,
      'connections': connections,
    };
  }

  factory KramFlowElement.fromMap(Map<String, dynamic> map) {
    return KramFlowElement(
      id: map['id'],
      text: map['text'] ?? '',
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      type: FlowShapeType.values[map['type'] ?? 0],
      connections: List<String>.from(map['connections'] ?? []),
    );
  }
}

// --- Note Models ---

class KramNote {
  final String id;
  String content;
  double x;
  double y;
  final String authorName;
  final String authorId;
  final int colorIndex; // For sticky note color

  KramNote({
    required this.id,
    required this.content,
    required this.x,
    required this.y,
    required this.authorName,
    required this.authorId,
    required this.colorIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'x': x,
      'y': y,
      'authorName': authorName,
      'authorId': authorId,
      'colorIndex': colorIndex,
    };
  }

  factory KramNote.fromMap(Map<String, dynamic> map) {
    return KramNote(
      id: map['id'],
      content: map['content'] ?? '',
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      authorName: map['authorName'] ?? 'Anonymous',
      authorId: map['authorId'] ?? '',
      colorIndex: map['colorIndex'] ?? 0,
    );
  }
}
