import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'editor.dart';
import 'note.dart';
import 'grid_view.dart';

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
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber, brightness: Brightness.dark)),
      home: const HomeScreen(),
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
    final String? notesString = prefs.getString('local_notes_v4');
    if (notesString != null) {
      final List<dynamic> decodedList = jsonDecode(notesString);
      setState(() { _notes = decodedList.map((item) => Note.fromMap(item)).toList(); });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(_notes.map((note) => note.toMap()).toList());
    await prefs.setString('local_notes_v4', encodedList);
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
                        Expanded(child: TextField(controller: textController, decoration: const InputDecoration(hintText: 'Новый раздел'))),
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
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Готово'))],
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

    // Создаем строго типизированный список вкладок-виджетов
    final List<Widget> tabViews = _categories.map((category) {
      final filteredNotes = category == 'Все' ? _notes : _notes.where((n) => n.category == category).toList();
      return NotesGrid(
        filteredNotes: filteredNotes,
        categories: _categories,
        onDelete: _deleteNote,
        onUpdate: (note, result) {
          setState(() {
            int idx = _notes.indexWhere((n) => n.id == note.id);
            if (idx != -1) {
              _notes[idx] = Note(id: note.id, title: result['title'], content: result['content'], category: result['category']);
            }
          });
          _saveNotes();
        },
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (category == 'Все') {
              final item = _notes.removeAt(oldIndex);
              _notes.insert(newIndex, item);
            } else {
              final tabNotes = _notes.where((n) => n.category == category).toList();
              final item = tabNotes.removeAt(oldIndex);
              tabNotes.insert(newIndex, item);
              final otherNotes = _notes.where((n) => n.category != category).toList();
              _notes = [...tabNotes, ...otherNotes];
            }
          });
          _saveNotes();
        },
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой Блокнот'),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: _manageCategories)],
        bottom: TabBar(controller: _tabController, isScrollable: true, tabs: _categories.map((cat) => Tab(text: cat)).toList()),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabViews,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditorScreen(categories: _categories)));
          if (result != null) {
            setState(() {
              _notes.add(Note(id: DateTime.now().millisecondsSinceEpoch.toString(), title: result['title'], content: result['content'], category: result['category']));
            });
            _saveNotes();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
