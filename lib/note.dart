class Note {
  String id;
  String title;
  String contentDelta;
  String category;

  Note({required this.id, required this.title, required this.contentDelta, required this.category});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'contentDelta': contentDelta, 'category': category};

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] ?? '',
      contentDelta: map['contentDelta'] ?? '[{"insert":"\\n"}]',
      category: map['category'] ?? 'Личное',
    );
  }
}
