class Note {
  String id;
  String title;
  String content;
  String category;

  Note({required this.id, required this.title, required this.content, required this.category});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'content': content, 'category': category};

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? 'Личное',
    );
  }
}
