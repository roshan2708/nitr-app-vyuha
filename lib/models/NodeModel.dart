class NodeModel {
  String id;
  String text;
  String parentId; // optional, for tree structure
  String authorId;
  NodeModel({
    required this.id,
    required this.text,
    required this.parentId,
    required this.authorId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'parentId': parentId,
      'authorId': authorId,
    };
  }

  factory NodeModel.fromMap(Map<String, dynamic> m) {
    return NodeModel(
      id: m['id'] as String,
      text: m['text'] as String,
      parentId: m['parentId'] as String? ?? '',
      authorId: m['authorId'] as String? ?? '',
    );
  }
}