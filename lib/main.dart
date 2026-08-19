import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fleather/fleather.dart';

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
  String contentJson;
  String category;

  Note({required this.id, required this.title, required this.contentJson, required this.category});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'contentJson': contentJson, 'category': category};

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] ?? '',
      contentJson: map['contentJson'] ?? '[{"insert":"\\n"}]',
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _categories = prefs.getStringList('local_categories') ?? ['Все', 'Личное', 'Работа', 'Идеи', 'Покупки'];
      _tabController = TabController(length: _categories.length, vsync: this);
      final String? notesString = prefs.getString('local_notes_v5');
      if (notesString != null) {
        final List<dynamic> decodedList = jsonDecode(notesString);
        _notes = decodedList.map((item) => Note.fromMap(item)).toList();
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('local_categories', _categories);
    final String encodedList = jsonEncode(_notes.map((note) => note.toMap()).toList());
    await prefs.setString('local_notes_v5', encodedList);
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой Блокнот'),
        bottom: TabBar(controller: _tabController, isScrollable: true, tabs: _categories.map((cat) => Tab(text: cat)).toList()),
      ),
      body: TabBarView(
        controller: _tabController!,
        children: _categories.map((category) {
          final filteredNotes = category == 'Все' ? _notes : _notes.where((n) => n.category == category).toList();
          
          if (filteredNotes.isEmpty) {
            return const Center(child: Text('Здесь пока пусто', style: TextStyle(color: Colors.white54)));
          }

          // Полноценная двухколоночная сетка с поддержкой перетаскивания плиток жестами
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: filteredNotes.length,
              itemBuilder: (context, index) {
                final note = filteredNotes[index];
                return LongPressDraggable<Note>(
                  data: note,
                  feedback: SizedBox(
                    width: MediaQuery.of(context).size.width / 2.2,
                    height: 100,
                    child: Card(elevation: 4, child: Center(child: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)))),
                  ),
                  childWhenDragging: Container(color: Colors.transparent),
                  child: DragTarget<Note>(
                    onAcceptWithDetails: (details) {
                      final draggedNote = details.data;
                      setState(() {
                        final int oldIdx = _notes.indexOf(draggedNote);
                        final int newIdx = _notes.indexOf(note);
                        if (oldIdx != -1 && newIdx != -1) {
                          final item = _notes.removeAt(oldIdx);
                          _notes.insert(newIdx, item);
                        }
                      });
                      _saveData();
                    },
                    builder: (context, candidateData, rejectedData) {
                      return GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditorScreen(note: note, categories: _categories)));
                          if (result != null) {
                            setState(() {
                              int idx = _notes.indexWhere((n) => n.id == note.id);
                              if (idx != -1) _notes[idx] = Note(id: note.id, title: result['title'], contentJson: result['contentJson'], category: result['category']);
                            });
                            _saveData();
                          }
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Указать категорию или удалить?'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    setState(() { _notes.removeWhere((n) => n.id == note.id); });
                                    _saveData();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                                ),
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                              ],
                            ),
                          );
                        },
                        child: Card(
                          elevation: 2,
                          color: candidateData.isNotEmpty ? Colors.amber.withOpacity(0.2) : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(note.title.isEmpty ? 'Без названия' : note.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                  child: Text(note.category, style: const TextStyle(fontSize: 10, color: Colors.amber)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditorScreen(categories: _categories)));
          if (result != null) {
            setState(() {
              _notes.add(Note(id: DateTime.now().millisecondsSinceEpoch.toString(), title: result['title'], contentJson: result['contentJson'], category: result['category']));
            });
            _saveData();
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
  FleatherController? _controller;
  final FocusNode _focusNode = FocusNode();
  String _selectedCategory = 'Личное';

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _selectedCategory = widget.note!.category;
      final doc = ParchmentDocument.fromJson(jsonDecode(widget.note!.contentJson));
      _controller = FleatherController(document: doc);
    } else {
      _controller = FleatherController();
      _selectedCategory = widget.categories.contains('Личное') ? 'Личное' : widget.categories.first;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметка'),
        actions: [
          DropdownButton<String>(
            value: _selectedCategory,
            items: widget.categories.where((cat) => cat != 'Все').map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
            onChanged: (val) { if (val != null) setState(() => _selectedCategory = val); },
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              final jsonText = jsonEncode(_controller!.document.toJson());
              Navigator.pop(context, {'title': _titleController.text, 'contentJson': jsonText, 'category': _selectedCategory});
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
              child: FleatherEditor(controller: _controller!, focusNode: _focusNode),
            ),
          ),
          // Обертка в Material решает проблему пустых перечеркнутых квадратов на Android
          Material(
            elevation: 4,
            color: Theme.of(context).cardColor,
            child: FleatherToolbar.basic(controller: _controller!),
          ),
        ],
      ),
    );
  }
}
