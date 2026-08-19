import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const LocalNotesApp());

class LocalNotesApp extends StatelessWidget {
  const LocalNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Локальный Блокнот',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber, 
          brightness: Brightness.dark
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class Note {
  String title;
  String content;
  Note({required this.title, required this.content});

  // Превращаем заметку в карту для сохранения в JSON
  Map<String, dynamic> toMap() => {'title': title, 'content': content};

  // Восстанавливаем заметку из JSON
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(title: map['title'] ?? '', content: map['content'] ?? '');
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes(); // Загружаем заметки из памяти при старте
  }

  // ЗАГРУЗКА ИЗ ПАМЯТИ ТЕЛЕФОНА
  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesString = prefs.getString('local_notes');
    if (notesString != null) {
      final List<dynamic> decodedList = jsonDecode(notesString);
      setState(() {
        _notes = decodedList.map((item) => Note.fromMap(item)).toList();
      });
    }
  }

  // СОХРАНЕНИЕ В ПАМЯТЬ ТЕЛЕФОНА
  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(_notes.map((note) => note.toMap()).toList());
    await prefs.setString('local_notes', encodedList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои заметки')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: _notes.isEmpty
            ? const Center(child: Text('Нет заметок. Нажмите +, чтобы добавить.'))
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // Плитки в стиле Google Keep
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  final note = _notes[index];
                  return Card(
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
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              note.content,
                              style: const TextStyle(fontSize: 14, color: Colors.white70),
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final Note? newNote = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EditorScreen()),
          );
          if (newNote != null) {
            setState(() {
              _notes.add(newNote);
            });
            _saveNotes(); // Сохраняем обновленный список на диск
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  void _insertFormat(String startTag, String endTag) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final selectedText = selection.textInside(text);
    final newText = text.replaceRange(selection.start, selection.end, '$startTag$selectedText$endTag');
    
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + startTag.length + selectedText.length + endTag.length
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая заметка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(
                context,
                Note(title: _titleController.text, content: _contentController.text),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: 'Заголовок', border: InputBorder.none),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(hintText: 'Заметка...', border: InputBorder.none),
              ),
            ),
          ),
          // Панель в стиле Xiaomi
          Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.format_bold),
                  onPressed: () => _insertFormat('**', '**'),
                ),
                IconButton(
                  icon: const Icon(Icons.format_italic),
                  onPressed: () => _insertFormat('*', '*'),
                ),
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted),
                  onPressed: () => _insertFormat('\n• ', ''),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
