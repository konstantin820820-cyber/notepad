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
      category: map['category'] ?? 'Личное',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Note> _notes = [];
  List<String> _categories = ['Все', 'Личное', 'Работа', 'Идеи', 'Покупки'];
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _initTabsAndData();
  }

  void _initTabsAndData() async {
    _tabController = TabController(length: _categories.length, vsync: this);
    await _loadCategories();
    await _loadNotes();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedCats = prefs.getStringList('local_categories');
    if (savedCats != null && savedCats.isNotEmpty) {
      setState(() {
        _categories = savedCats;
        _tabController = TabController(length: _categories.length, vsync: this);
      });
    }
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('local_categories', _categories);
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

  void _manageCategories() {
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Управление разделами'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            decoration: const InputDecoration(hintText: 'Новый раздел'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.amber),
                          onPressed: () {
                            if (textController.text.trim().isNotEmpty && !_categories.contains(textController.text.trim())) {
                              setState(() {
                                _categories.add(textController.text.trim());
                                _tabController = TabController(length: _categories.length, vsync: this);
                              });
                              _saveCategories();
                              setDialogState(() {});
                              textController.clear();
                            }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SizedBox(
                        height: 200,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            if (cat == 'Все' || cat == 'Личное') return const SizedBox();
                            return ListTile(
                              title: Text(cat),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    for (var note in _notes) {
                                      if (note.category == cat) note.category = 'Личное';
                                    }
                                    _categories.remove(cat);
                                    _tabController = TabController(length: _categories.length, vsync: this);
                                  });
                                  _saveNotes();
                                  _saveCategories();
                                  setDialogState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Готово'))
              ],
            );
          },
        );
      },
    );
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
    if (_tabController == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой Блокнот'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _manageCategories,
          )
        ],
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
