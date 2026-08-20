import 'package:flutter/material.dart';
import 'package:reorderableitemsview/reorderableitemsview.dart';
import 'note.dart';

class NotesGridView extends StatelessWidget {
  final List<Note> notes;
  final Function(int, int) onReorder;
  final Function(Note) onNoteTap;

  const NotesGridView({
    Key? key,
    required this.notes,
    required this.onReorder,
    required this.onNoteTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReorderableItemsView(
      crossAxisCount: 2, // 2 колонки как в Google Keep
      mainAxisSpacing: 8.0,
      crossAxisSpacing: 8.0,
      padding: const EdgeInsets.all(8.0),
      onReorder: onReorder,
      children: notes.map((note) {
        return WidgetItem(
          key: ValueKey(note.id), // Важно: у каждой заметки должен быть уникальный id
          child: Card(
            elevation: 2,
            child: InkWell(
              onTap: () => onNoteTap(note),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                // Здесь отображается превью вашей заметки
                child: Column(
                  crossAxisAlignment: start,
                  children: [
                    Text(
                      note.title.isEmpty ? 'Без названия' : note.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Fleather хранит данные как Delta, для превью берем чистый текст, если возможно
                    Text(
                      note.plainText, 
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
