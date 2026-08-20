import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мой Локальный Блокнот',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E)),
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: const MainScreen(),
    );
  }
}

class Note {
  final String id;
  final String title;
  final String contentJson;
  final String category;

  Note({
    required this.id,
    required this.title,
    required this.contentJson,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'contentJson': contentJson,
      'category': category,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      contentJson: map['contentJson'] ?? '',
      category: map['category'] ?? 'Личное',
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Note> _notes = [];
  List<String> _categories = ['Все', 'Личное', 'Работа', 'Идеи', 'Покупки'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final notesString = prefs.getString('notes');
    final catsString = prefs.getString('categories');

    if (notesString != null) {
      final List<dynamic> decoded = jsonDecode(notesString);
      setState(() {
        _notes = decoded.map((item) => Note.fromMap(item)).toList();
      });
    }
    if (catsString != null) {
      setState(() {
        _categories = List<String>.from(jsonDecode(catsString));
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final notesString = jsonEncode(_notes.map((n) => n.toMap()).toList());
    final catsString = jsonEncode(_categories);
    await prefs.setString('notes', notesString);
    await prefs.setString('categories', catsString);
  }

  void _manageCategories() {
    showDialog(
      context: context,
      builder: (context) {
        String newCat = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Управление категориями'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(hintText: 'Новая категория'),
                      onChanged: (val) => newCat = val,
                    ),
                    TextButton(
                      onPressed: () {
                        if (newCat.trim().isNotEmpty && !_categories.contains(newCat.trim())) {
                          setState(() { _categories.add(newCat.trim()); });
                          setDialogState(() {});
                          _saveData();
                        }
                      },
                      child: const Text('Добавить'),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          if (cat == 'Все' || cat == 'Личное') return Container();
                          return ListTile(
                            title: Text(cat),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _categories.remove(cat);
                                  _notes = _notes.map((n) => n.category == cat ? Note(id: n.id, title: n.title, contentJson: n.contentJson, category: 'Личное') : n).toList();
                                });
                                setDialogState(() {});
                                _saveData();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
              ],
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Мой Блокнот'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _manageCategories,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: _categories.map((cat) => Tab(text: cat)).toList(),
          ),
        ),
        body: TabBarView(
          children: _categories.map((category) {
            final filteredNotes = category == 'Все' 
                ? _notes 
                : _notes.where((n) => n.category == category).toList();

            if (filteredNotes.isEmpty) {
              return const Center(child: Text('Нет заметок'));
            }

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                  childAspectRatio: 1.1,
                ),
                itemCount: filteredNotes.length,
                itemBuilder: (context, index) {
                  final note = filteredNotes[index];
                  return LongPressDraggable<Note>(
                    data: note,
                    axis: null,
                    feedback: SizedBox(
                      width: MediaQuery.of(context).size.width / 2.3,
                      height: 110,
                      child: Card(
                        elevation: 6,
                        color: Colors.amber.withOpacity(0.9),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            note.title.isEmpty ? 'Без названия' : note.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.2,
                      child: Card(child: Container()),
                    ),
                    child: DragTarget<Note>(
                      onWillAcceptWithDetails: (details) => details.data.id != note.id,
                      onAcceptWithDetails: (details) {
                        final draggedNote = details.data;
                        setState(() {
                          final int oldIdx = _notes.indexWhere((n) => n.id == draggedNote.id);
                          final int newIdx = _notes.indexWhere((n) => n.id == note.id);
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
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EditorScreen(note: note, categories: _categories)),
                            );
                            if (result != null) {
                              setState(() {
                                int idx = _notes.indexWhere((n) => n.id == note.id);
                                if (idx != -1) {
                                  _notes[idx] = Note(
                                    id: note.id,
                                    title: result['title'],
                                    contentJson: result['contentJson'],
                                    category: result['category'],
                                  );
                                }
                              });
                              _saveData();
                            }
                          },
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Удалить заметку?'),
                                content: const Text('Это действие нельзя отменить.'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() { _notes.removeWhere((n) => n.id == note.id); });
                                      _saveData();
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Отмена'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Card(
                            elevation: 2,
                            color: candidateData.isNotEmpty ? Colors.amber.withOpacity(0.3) : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    note.title.isEmpty ? 'Без названия' : note.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EditorScreen(categories: _categories)),
            );
            if (result != null) {
              setState(() {
                _notes.add(Note(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: result['title'],
                  contentJson: result['contentJson'],
                  category: result['category'],
                ));
              });
              _saveData();
            }
          },
          child: const Icon(Icons.add),
        ),
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

  Future<void> _exportToTxtFile(BuildContext context, String title, String plainText) async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    }

    try {
      Directory directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      }

      String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (safeTitle.trim().isEmpty) safeTitle = "Заметка_${DateTime.now().millisecondsSinceEpoch}";

      String filePath = '${directory.path}/$safeTitle.txt';
      File file = File(filePath);

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FleatherEditor(controller: _controller!, focusNode: _focusNode),
            ),
          ),
        ],
      ),
    );
  }
} // <--- Это самая последняя строчка в файле!
