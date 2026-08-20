import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fleather/fleather.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

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

class Note {
  String id, title, contentJson, category;
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
  void initState() { super.initState(); _initTabsAndData(); }

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
    await prefs.setString('local_notes_v5', jsonEncode(_notes.map((note) => note.toMap()).toList()));
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
          if (filteredNotes.isEmpty) return const Center(child: Text('Здесь пока пусто', style: TextStyle(color: Colors.white54)));
          
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ReorderableGridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.1),
              itemCount: filteredNotes.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  final item = _notes.removeAt(_notes.indexOf(filteredNotes[oldIndex]));
                  _notes.insert(_notes.indexOf(filteredNotes[newIndex]), item);
                });
                _saveData();
              },
              itemBuilder: (context, index) {
                final note = filteredNotes[index];
                return GestureDetector(
                  key: ValueKey(note.id),
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
                        title: const Text('Удалить заметку?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                          TextButton(onPressed: () { setState(() { _notes.removeWhere((n) => n.id == note.id); }); _saveData(); Navigator.pop(context); }, child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                  },
                  child: Card(
                    elevation: 2,
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
      _controller = FleatherController(document: ParchmentDocument.fromJson(jsonDecode(widget.note!.contentJson)));
    } else {
      _controller = FleatherController();
      _selectedCategory = widget.categories.contains('Личное') ? 'Личное' : widget.categories.first;
    }
  }

  void _saveToHtmlFile() async {
    try {
      final converter = const FleatherHtmlCodec();
      final String htmlContent = converter.encode(_controller!.document.toDelta());
      final String fileName = _titleController.text.trim().isEmpty ? "Заметка_${DateTime.now().millisecondsSinceEpoch}" : _titleController.text.trim();
      final directory = Directory('/storage/emulated/0/Download');
      final targetDir = await directory.exists() ? directory : Directory('/sdcard/Download');
      final file = File('${targetDir.path}/$fileName.html');
      await file.writeAsString("""
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>${_titleController.text}</title>
          <style>body { font-family: sans-serif; padding: 20px; background: #121212; color: #fff; }</style>
        </head>
        <body>
          <h2>${_titleController.text}</h2>
          $htmlContent
        </body>
        </html>
      """);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Красивый HTML сохранен в Загрузки: $fileName.html')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка при сохранении файла.')));
      }
    }
  }

  void _copyToClipboard() {
    final String plainText = _controller!.document.toPlainText();
    Clipboard.setData(ClipboardData(text: "${_titleController.text}\n\n$plainText")).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст заметки скопирован в буфер обмена!')));
      }
    });
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
          IconButton(icon: const Icon(Icons.copy), onPressed: _copyToClipboard, tooltip: 'Копировать в буфер'),
          IconButton(icon: const Icon(Icons.save_alt), onPressed: _saveToHtmlFile, tooltip: 'Скачать как .html'),
          DropdownButton<String>(
            value: _selectedCategory,
            items: widget.categories.where((cat) => cat != 'Все').map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
            onChanged: (val) { if (val != null) setState(() => _selectedCategory = val); },
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, {'title': _titleController.text, 'contentJson': jsonEncode(_controller!.document.toJson()), 'category': _selectedCategory});
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: TextField(controller: _titleController, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: 'Заголовок', border: InputBorder.none))),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: FleatherEditor(controller: _controller!, focusNode: _focusNode))),
          Material(elevation: 4, child: FleatherToolbar.basic(controller: _controller!))
        ],
      ),
    );
  }
}
