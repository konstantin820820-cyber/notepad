import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'editor.dart';

void main() => runApp(const LocalNotesApp());

class LocalNotesApp extends StatelessWidget {
  const LocalNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Локальный Блокнот',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru', 'RU')],
      locale: const Locale('ru', 'RU'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber, brightness: Brightness.dark),
      ),
      home: const HomeScreen(),
    );
  }
}

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
    final String? notesString = prefs.getString('local_notes_v3');
    if (notesString != null) {
      final List<dynamic> decodedList = jsonDecode(notesString);
      setState(() { _notes = decodedList.map((item) => Note.fromMap(item)).toList(); });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(_notes.map((note) => note.toMap()).toList());
    await prefs.setString('local_notes_v3', encodedList);
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
          final filteredNotes = category == 'Все' ? _notes : _notes.where((n) => n.category == category).toList();
          return filteredNotes.isEmpty
              ? const Center(child: Text('Здесь пока пусто', style: TextStyle(color: Colors.white54)))
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.9,
                    ),
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = filteredNotes[index];
                      String previewText = "";
                      try {
                        final List<dynamic> json = jsonDecode(note.contentDelta);
                        previewText = json.map((e) => e['insert'] ?? '').join().trim();
                      } catch (_) {
                        previewText = note.contentDelta;
                      }
                      return GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => EditorScreen(
                              id: note.id, title: note.title, contentDelta: note.contentDelta, category: note.category, categories: _categories,
                            )),
                          );
                          if (result != null) {
                            setState(() {
                              int idx = _notes.indexWhere((n) => n.id == note.id);
                              if (idx != -1) _notes[idx] = Note(id: note.id, title: result['title'], contentDelta: result['contentDelta'], category: result['category']);
                            });
                            _saveNotes();
                          }
                        },
                        onLongPress: () => _deleteNote(note),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note.title.isEmpty ? 'Без названия' : note.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                  child: Text(note.category, style: const TextStyle(fontSize: 10, color: Colors.amber)),
                                ),
                                const SizedBox(height: 6),
                                Expanded(child: Text(previewText, style: const TextStyle(fontSize: 13, color: Colors.white70), maxLines: 4, overflow: TextOverflow.ellipsis)),
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
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditorScreen(categories: _categories)),
          );
          if (result != null) {
            setState(() {
              _notes.add(Note(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: result['title'],
                contentDelta: result['contentDelta'],
                category: result['category'],
              ));
            });
            _saveNotes();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
