import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'note.dart';
import 'editor.dart';

class NotesGrid extends StatelessWidget {
  final List<Note> filteredNotes;
  final List<String> categories;
  final Function(Note) onDelete;
  final Function(Note, Map<String, dynamic>) onUpdate;
  final Function(int, int) onReorder;

  const NotesGrid({
    super.key,
    required this.filteredNotes,
    required this.categories,
    required this.onDelete,
    required this.onUpdate,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (filteredNotes.isEmpty) {
      return const Center(child: Text('Здесь пока пусто', style: TextStyle(color: Colors.white54)));
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ReorderableGridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.9,
        ),
        itemCount: filteredNotes.length,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          final note = filteredNotes[index];
          
          // Очищаем превью текста на плитке от знаков Markdown для красоты
          String cleanPreview = note.content
              .replaceAll('**', '')
              .replaceAll('*', '')
              .replaceAll('<bg>', '')
              .replaceAll('</bg>', '');

          return GestureDetector(
            key: ValueKey(note.id), // Уникальный ключ для перетаскивания плиток жестами
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditorScreen(
                  id: note.id,
                  title: note.title,
                  content: note.content, // Передаем чистое текстовое поле вместо Delta
                  category: note.category,
                  categories: categories,
                )),
              );
              if (result != null) onUpdate(note, result);
            },
            onLongPress: () => onDelete(note),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? 'Без названия' : note.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                      child: Text(note.category, style: const TextStyle(fontSize: 10, color: Colors.amber)),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        cleanPreview.isEmpty ? 'Пустая заметка' : cleanPreview,
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
