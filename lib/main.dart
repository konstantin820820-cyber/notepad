import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const LocalNotesApp());

class LocalNotesApp extends StatelessWidget {
  const LocalNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Локальный Блокнот',
      // Полная русификация системных контекстных меню (копировать/вставить)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru', 'RU')],
      locale: const Locale('ru', 'RU'),
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

// Обновленная модель заметки с поддержкой тем и сложного форматирования
class Note {
  String id;
  String title;
  String contentDelta; // Хранит стили текста (жирный, цвет и т.д.) в формате JSON
  String category;

  Note({
    required this.id,
    required this.title,
    required this.contentDelta,
    required this.category
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'contentDelta': contentDelta,
    'category': category,
  };

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] ?? '',
      contentDelta: map['contentDelta'] ?? '[{"insert":"\\n"}]',
      category: map['category'] ?? 'Все',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Note> _notes = [];
  // Список наших тем (категорий)
  final List<String> _categories = ['Все', 'Личное', 'Работа', 'Идеи', 'Покупки'];
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesString = prefs.getString('local_notes_v2');
    if (notesString != null) {
      final List<dynamic> decodedList = jsonDecode(notesString);
      setState(() {
        _notes = decodedList.map((item) => Note.fromMap(item)).toList();
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(_notes.map((note) => note.toMap()).toList());
    await prefs.setString('local_notes_v2', encodedList);
  }

  // Фильтрация заметок по выбранной вкладке-теме
  List<Note> _getFilteredNotes(String category) {
    if (category == 'Все') return _notes;
    return _notes.where((note) => note.category == category).toList();
  }

  void _deleteNote(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заметку?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              setState(() { _notes.removeWhere((n) => n.id == note.id); });
              _saveNotes();
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой Блокнот'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _categories.map((cat) => Tab(text: cat)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _categories.map((category) {
          final filteredNotes = _getFilteredNotes(category);
          return filteredNotes.isEmpty
              ? const Center(child: Text('Здесь пока пусто', style: TextStyle(color: Colors.white54)))
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = filteredNotes[index];
                      // Простой парсинг для превью текста в плитке
                      String previewText = "";
                      try {
                        final List<dynamic> json = jsonDecode(note.contentDelta);
                        previewText = json.map((e) => e['insert'] ?? '').join().trim();
                      } catch (_) {
                        previewText = note.contentDelta;
                      }

                      return GestureDetector(
                        onTap: () async {
                          // ОТКРЫТИЕ НА РЕДАКТИРОВАНИЕ
                          final Note? updatedNote = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => EditorScreen(note: note, categories: _categories)),
                          );
                          if (updatedNote != null) {
                            setState(() {
                              int idx = _notes.indexWhere((n) => n.id == note.id);
                              if (idx != -1) _notes[idx] = updatedNote;
                            });
                            _saveNotes();
                          }
                        },
                        onLongPress: () => _deleteNote(note), // Удаление долгим тапом
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
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(4)
                                  ),
                                  child: Text(note.category, style: const TextStyle(fontSize: 10, color: Colors.amber)),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Text(
                                    previewText,
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
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // СОЗДАНИЕ НОВОЙ ЗАМЕТКИ
          final Note? newNote = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditorScreen(categories: _categories)),
          );
          if (newNote != null) {
            setState(() { _notes.add(newNote); });
            _saveNotes();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class EditorScreen extends StatefulWidget {
  final Note? note;
  final List<String> categories;
  const EditorScreen({super.key, this.note, required this.categories});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  quill.QuillController? _quillController;
  String _selectedCategory = 'Личное';

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _selectedCategory = widget.note!.category;
      try {
        final doc = quill.Document.fromJson(jsonDecode(widget.note!.contentDelta));
        _quillController = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
      } catch (_) {
        _quillController = quill.QuillController.basic();
      }
    } else {
      _quillController = quill.QuillController.basic();
      if (widget.categories.contains('Личное')) {
        _selectedCategory = 'Личное';
      } else {
