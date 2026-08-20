import 'dart:convert';

class Note {
  final String id;
  String title;
  String content;   // Здесь Fleather хранит JSON-строку со всеми жирными/курсивными стилями
  String plainText; // Чистый текст без стилей для превью и сохранения в .txt
  String category;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.plainText,
    required this.category,
  });

  // Превращаем заметку в карту (Map) для сохранения в Shared Preferences
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'plainText': plainText,
      'category': category,
    };
  }

  // Восстанавливаем заметку из памяти телефона
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      plainText: map['plainText'] ?? '',
      category: map['category'] ?? 'Личное',
    );
  }

  String toJson() => json.encode(toMap());
  factory Note.fromJson(String source) => Note.fromMap(json.decode(source));
}
