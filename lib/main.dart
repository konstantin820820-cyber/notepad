import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fleather/fleather.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

void main() {
  runApp(const LocalNotesApp());
}

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

      supportedLocales: const [
        Locale('ru', 'RU'),
      ],

      locale: const Locale('ru', 'RU'),

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
      ),

      home: const HomeScreen(),
    );
  }
}

// ============================================================
// NOTE
// ============================================================

class Note {
  String id;
  String title;
  String contentJson;
  String category;

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
      id: map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),

      title: map['title']?.toString() ?? '',

      contentJson:
          map['contentJson']?.toString() ?? '[{"insert":"\\n"}]',

      category:
          map['category']?.toString() ?? 'Личное',
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  List<Note> _notes = [];

  List<String> _categories = [
    'Все',
    'Личное',
    'Работа',
    'Идеи',
    'Покупки',
  ];

  TabController? _tabController;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ==========================================================
  // LOAD
  // ==========================================================

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCategories =
        prefs.getStringList('local_categories');

    final notesString =
        prefs.getString('local_notes_v5');

    List<String> categories;

    if (savedCategories == null || savedCategories.isEmpty) {
      categories = [
        'Все',
        'Личное',
        'Работа',
        'Идеи',
        'Покупки',
      ];
    } else {
      categories = List<String>.from(savedCategories);

      // "Все" всегда должен существовать первым.
      categories.removeWhere((c) => c == 'Все');
      categories.insert(0, 'Все');
    }

    List<Note> notes = [];

    if (notesString != null && notesString.isNotEmpty) {
      try {
        final decoded = jsonDecode(notesString);

        if (decoded is List) {
          notes = decoded
              .map((item) => Note.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList();
        }
      } catch (_) {
        notes = [];
      }
    }

    // Если старые заметки содержат категорию,
    // которой больше нет — переносим их в первый
    // пользовательский раздел.
    final fallbackCategory =
        categories.length > 1 ? categories[1] : 'Личное';

    for (final note in notes) {
      if (!categories.contains(note.category)) {
        note.category = fallbackCategory;
      }
    }

    _tabController?.dispose();

    _tabController = TabController(
      length: categories.length,
      vsync: this,
    );

    _tabController!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    setState(() {
      _categories = categories;
      _notes = notes;
      _loading = false;
    });
  }

  // ==========================================================
  // SAVE
  // ==========================================================

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'local_categories',
      _categories,
    );

    await prefs.setString(
      'local_notes_v5',
      jsonEncode(
        _notes.map((note) => note.toMap()).toList(),
      ),
    );
  }

  // ==========================================================
  // TAB CONTROLLER
  // ==========================================================

  void _recreateTabController({
    int selectedIndex = 0,
  }) {
    _tabController?.dispose();

    _tabController = TabController(
      length: _categories.length,
      vsync: this,
    );

    final safeIndex = selectedIndex.clamp(
      0,
      _categories.length - 1,
    );

    _tabController!.index = safeIndex;

    _tabController!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    setState(() {});
  }

  // ==========================================================
  // ADD CATEGORY
  // ==========================================================

  Future<void> _addCategory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Новый раздел'),

          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Название',
              hintText: 'Например: Статьи',
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),

            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name == null || name.trim().isEmpty) {
      return;
    }

    final newName = name.trim();

    if (_categories.contains(newName)) {
      _showMessage('Такой раздел уже существует');
      return;
    }

    final oldIndex = _tabController?.index ?? 0;

    setState(() {
      _categories.add(newName);
    });

    _recreateTabController(
      selectedIndex: _categories.length - 1,
    );

    await _saveData();

    _showMessage('Раздел «$newName» добавлен');
  }

  // ==========================================================
  // RENAME CATEGORY
  // ==========================================================

  Future<void> _renameCategory(String category) async {
    if (category == 'Все') {
      return;
    }

    final controller =
        TextEditingController(text: category);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Переименовать раздел'),

          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),

            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newName == null ||
        newName.trim().isEmpty ||
        newName.trim() == category) {
      return;
    }

    final trimmed = newName.trim();

    if (_categories.contains(trimmed)) {
      _showMessage('Такой раздел уже существует');
      return;
    }

    setState(() {
      final index = _categories.indexOf(category);

      if (index != -1) {
        _categories[index] = trimmed;
      }

      for (final note in _notes) {
        if (note.category == category) {
          note.category = trimmed;
        }
      }
    });

    final selectedIndex =
        _categories.indexOf(trimmed);

    _recreateTabController(
      selectedIndex: selectedIndex,
    );

    await _saveData();

    _showMessage('Раздел переименован');
  }

  // ==========================================================
  // DELETE CATEGORY
  // ==========================================================

  Future<void> _deleteCategory(String category) async {
    if (category == 'Все') {
      return;
    }

    final notesCount =
        _notes.where((n) => n.category == category).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить раздел?'),

          content: Text(
            notesCount == 0
                ? 'Раздел «$category» пуст.'
                : 'В разделе «$category» находится '
                    '$notesCount заметок.\n\n'
                    'Заметки будут перенесены в первый '
                    'доступный раздел.',
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final targetCategory =
        _categories.firstWhere(
      (c) => c != 'Все' && c != category,
      orElse: () => 'Личное',
    );

    setState(() {
      _categories.remove(category);

      for (final note in _notes) {
        if (note.category == category) {
          note.category = targetCategory;
        }
      }
    });

    final selectedIndex =
        (_tabController?.index ?? 0)
            .clamp(0, _categories.length - 1);

    _recreateTabController(
      selectedIndex: selectedIndex,
    );

    await _saveData();

    _showMessage('Раздел удалён');
  }

  // ==========================================================
  // MANAGE CATEGORIES
  // ==========================================================

  Future<void> _manageCategories() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              child: SizedBox(
                height:
                    MediaQuery.of(context).size.height * 0.75,

                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Разделы',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const Text(
                      'Удерживайте раздел и перетащите его',
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _categories.length - 1,

                        onReorder: (oldIndex, newIndex) async {
                          if (oldIndex < newIndex) {
                            newIndex--;
                          }

                          final fromIndex = oldIndex + 1;
                          final toIndex = newIndex + 1;

                          setState(() {
                            final item =
                                _categories.removeAt(fromIndex);

                            _categories.insert(
                              toIndex,
                              item,
                            );
                          });

                          modalSetState(() {});

                          final selectedCategory =
                              _categories[
                                  (_tabController?.index ?? 0)
                                      .clamp(
                                        0,
                                        _categories.length - 1,
                                      )];

                          _recreateTabController(
                            selectedIndex: _categories.indexOf(
                              selectedCategory,
                            ),
                          );

                          await _saveData();
                        },

                        itemBuilder: (context, index) {
                          final category =
                              _categories[index + 1];

                          return Card(
                            key: ValueKey(
                              'category_$category',
                            ),

                            child: ListTile(
                              leading: const Icon(
                                Icons.drag_handle,
                              ),

                              title: Text(category),

                              trailing: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Переименовать',
                                    icon: const Icon(
                                      Icons.edit,
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(
                                        context,
                                      );

                                      await _renameCategory(
                                        category,
                                      );
                                    },
                                  ),

                                  IconButton(
                                    tooltip: 'Удалить',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(
                                        context,
                                      );

                                      await _deleteCategory(
                                        category,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);

                                await _addCategory();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text(
                                'Добавить раздел',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // REORDER NOTES
  // ==========================================================

  void _reorderNotes(
    String category,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex) {
      return;
    }

    final visibleNotes = category == 'Все'
        ? List<Note>.from(_notes)
        : _notes
            .where((n) => n.category == category)
            .toList();

    if (oldIndex < 0 ||
        oldIndex >= visibleNotes.length) {
      return;
    }

    if (newIndex < 0 ||
        newIndex >= visibleNotes.length) {
      newIndex = visibleNotes.length - 1;
    }

    final moved = visibleNotes.removeAt(oldIndex);
    visibleNotes.insert(newIndex, moved);

    setState(() {
      if (category == 'Все') {
        _notes = visibleNotes;
      } else {
        // Сохраняем позиции заметок других разделов,
        // меняя только порядок заметок этого раздела.
        int visibleIndex = 0;

        for (int i = 0; i < _notes.length; i++) {
          if (_notes[i].category == category) {
            _notes[i] = visibleNotes[visibleIndex];
            visibleIndex++;
          }
        }
      }
    });

    _saveData();
  }

  // ==========================================================
  // DELETE NOTE
  // ==========================================================

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить заметку?'),

          content: Text(
            note.title.isEmpty
                ? 'Без названия'
                : note.title,
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                false,
              ),
              child: const Text('Отмена'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(
                context,
                true,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _notes.removeWhere(
        (n) => n.id == note.id,
      );
    });

    await _saveData();
  }

  // ==========================================================
  // EDIT NOTE
  // ==========================================================

  Future<void> _editNote(Note note) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(
          note: note,
          categories: _categories,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      final index = _notes.indexWhere(
        (n) => n.id == note.id,
      );

      if (index != -1) {
        _notes[index] = Note(
          id: note.id,
          title: result['title'] ?? '',
          contentJson:
              result['contentJson'] ?? '[{"insert":"\\n"}]',
          category:
              result['category'] ?? note.category,
        );
      }
    });

    await _saveData();
  }

  // ==========================================================
  // ADD NOTE
  // ==========================================================

  Future<void> _addNote() async {
    final defaultCategory =
        (_tabController?.index ?? 0) > 0
            ? _categories[_tabController!.index]
            : (_categories.length > 1
                ? _categories[1]
                : 'Личное');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(
          categories: _categories,
          initialCategory: defaultCategory,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _notes.add(
        Note(
          id: DateTime.now()
              .microsecondsSinceEpoch
              .toString(),

          title: result['title'] ?? '',

          contentJson:
              result['contentJson'] ??
                  '[{"insert":"\\n"}]',

          category:
              result['category'] ?? defaultCategory,
        ),
      );
    });

    await _saveData();
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (_loading ||
        _tabController == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой Блокнот'),

        actions: [
          IconButton(
            tooltip: 'Управление разделами',
            icon: const Icon(Icons.folder_open),
            onPressed: _manageCategories,
          ),
        ],

        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,

          tabs: _categories
              .map(
                (category) => Tab(
                  text: category,
                ),
              )
              .toList(),
        ),
      ),

      body: TabBarView(
        controller: _tabController!,

        children: _categories.map(
          (category) {
            final filteredNotes = category == 'Все'
                ? List<Note>.from(_notes)
                : _notes
                    .where(
                      (n) => n.category == category,
                    )
                    .toList();

            if (filteredNotes.isEmpty) {
              return Center(
                child: Text(
                  'Здесь пока пусто',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.54),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(8),

              child: ReorderableGridView.builder(
                padding: const EdgeInsets.only(
                  bottom: 90,
                ),

                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.1,
                ),

                itemCount: filteredNotes.length,

                dragStartDelay:
                    const Duration(milliseconds: 450),

                onReorder: (oldIndex, newIndex) {
                  _reorderNotes(
                    category,
                    oldIndex,
                    newIndex,
                  );
                },

                itemBuilder: (context, index) {
                  final note = filteredNotes[index];

                  return Card(
                    key: ValueKey(note.id),

                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(12),

                      // Обычный тап — открыть.
                      //
                      // ВАЖНО:
                      // здесь НЕТ onLongPress.
                      // Поэтому long-press теперь
                      // используется для перетаскивания.
                      onTap: () => _editNote(note),

                      child: Padding(
                        padding:
                            const EdgeInsets.all(12),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [
                                Expanded(
                                  child: Text(
                                    note.title.isEmpty
                                        ? 'Без названия'
                                        : note.title,

                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 16,
                                    ),

                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                  ),
                                ),

                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,

                                  icon: const Icon(
                                    Icons.more_vert,
                                    size: 20,
                                  ),

                                  onSelected:
                                      (value) async {
                                    if (value == 'delete') {
                                      await _deleteNote(
                                        note,
                                      );
                                    }
                                  },

                                  itemBuilder:
                                      (context) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons
                                                .delete_outline,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Удалить'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const Spacer(),

                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),

                              decoration:
                                  BoxDecoration(
                                color: Colors.white10,
                                borderRadius:
                                    BorderRadius.circular(
                                  4,
                                ),
                              ),

                              child: Text(
                                note.category,

                                style:
                                    const TextStyle(
                                  fontSize: 10,
                                  color: Colors.amber,
                                ),
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
          },
        ).toList(),
      ),

      floatingActionButton:
          FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}

// ============================================================
// EDITOR
// ============================================================

class EditorScreen extends StatefulWidget {
  final Note? note;
  final List<String> categories;
  final String? initialCategory;

  const EditorScreen({
    super.key,
    this.note,
    required this.categories,
    this.initialCategory,
  });

  @override
  State<EditorScreen> createState() =>
      _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _titleController =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();

  FleatherController? _controller;

  late String _selectedCategory;

  @override
  void initState() {
    super.initState();

    if (widget.note != null) {
      _titleController.text =
          widget.note!.title;

      _selectedCategory =
          widget.note!.category;

      try {
        _controller = FleatherController(
          document:
              ParchmentDocument.fromJson(
            jsonDecode(
              widget.note!.contentJson,
            ),
          ),
        );
      } catch (_) {
        _controller =
            FleatherController();
      }
    } else {
      _controller =
          FleatherController();

      final availableCategories =
          widget.categories
              .where((cat) => cat != 'Все')
              .toList();

      if (widget.initialCategory != null &&
          availableCategories.contains(
            widget.initialCategory,
          )) {
        _selectedCategory =
            widget.initialCategory!;
      } else if (availableCategories
          .contains('Личное')) {
        _selectedCategory = 'Личное';
      } else if (availableCategories
          .isNotEmpty) {
        _selectedCategory =
            availableCategories.first;
      } else {
        _selectedCategory = 'Личное';
      }
    }
  }

  // ==========================================================
  // HTML ESCAPE
  // ==========================================================

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  // ==========================================================
  // INLINE HTML
  // ==========================================================

  String _applyInlineAttributes(
    String text,
    Map<String, dynamic>? attributes,
  ) {
    if (text.isEmpty) {
      return '';
    }

    var result = _escapeHtml(text);

    if (attributes == null) {
      return result;
    }

    if (attributes['bold'] == true) {
      result = '<strong>$result</strong>';
    }

    if (attributes['italic'] == true) {
      result = '<em>$result</em>';
    }

    if (attributes['underline'] == true) {
      result = '<u>$result</u>';
    }

    if (attributes['strike'] == true) {
      result = '<s>$result</s>';
    }

    if (attributes['code'] == true) {
      result = '<code>$result</code>';
    }

    if (attributes['link'] != null) {
      final link =
          _escapeHtml(
        attributes['link'].toString(),
      );

      result =
          '<a href="$link">$result</a>';
    }

    return result;
  }

  // ==========================================================
  // DELTA -> HTML
  // ==========================================================

  String _deltaToHtml() {
    final delta =
        _controller!.document
            .toDelta()
            .toJson();

    final html = StringBuffer();

    html.write('''
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${_escapeHtml(_titleController.text)}</title>

<style>
body {
  font-family: sans-serif;
  line-height: 1.6;
  padding: 24px;
  max-width: 900px;
  margin: auto;
}

h1, h2, h3 {
  line-height: 1.25;
}

blockquote {
  margin: 12px 0;
  padding-left: 16px;
  border-left: 4px solid #999;
}

code {
  font-family: monospace;
  background: #eeeeee;
  padding: 2px 4px;
  border-radius: 4px;
}

a {
  color: #1565c0;
}

ul, ol {
  padding-left: 28px;
}

img {
  max-width: 100%;
  height: auto;
}
</style>
</head>
<body>
''');

    if (_titleController.text.trim().isNotEmpty) {
      html.write(
        '<h1>${_escapeHtml(_titleController.text.trim())}</h1>',
      );
    }

    String currentText = '';

    void writeParagraph(
      String text,
      Map<String, dynamic>? attributes,
    ) {
      final formatted =
          _applyInlineAttributes(
        text,
        attributes,
      );

      if (formatted.isEmpty) {
        html.write('<p><br></p>');
      } else {
        html.write('<p>$formatted</p>');
      }
    }

    for (final operation in delta) {
      if (operation is! Map) {
        continue;
      }

      if (!operation.containsKey('insert')) {
        continue;
      }

      final insert = operation['insert'];

      final attributes =
          operation['attributes'] is Map
              ? Map<String, dynamic>.from(
                  operation['attributes'],
                )
              : null;

      // Обычный текст.
      if (insert is String) {
        final parts = insert.split('\n');

        for (int i = 0;
            i < parts.length;
            i++) {
          currentText += parts[i];

          if (i < parts.length - 1) {
            final lineAttributes =
                attributes;

            final block =
                currentText;

            currentText = '';

            String? blockTag;

            if (lineAttributes != null) {
              if (lineAttributes['header'] == 1) {
                blockTag = 'h1';
              } else if (lineAttributes['header'] == 2) {
                blockTag = 'h2';
              } else if (lineAttributes['header'] == 3) {
                blockTag = 'h3';
              }
            }

            final formatted =
                _applyInlineAttributes(
              block,
              attributes,
            );

            if (blockTag != null) {
              html.write(
                '<$blockTag>$formatted</$blockTag>',
              );
            } else if (lineAttributes != null &&
                lineAttributes['blockquote'] == true) {
              html.write(
                '<blockquote>$formatted</blockquote>',
              );
            } else if (lineAttributes != null &&
                lineAttributes['list'] == 'bullet') {
              html.write(
                '<ul><li>$formatted</li></ul>',
              );
            } else if (lineAttributes != null &&
                lineAttributes['list'] == 'ordered') {
              html.write(
                '<ol><li>$formatted</li></ol>',
              );
            } else {
              writeParagraph(
                block,
                attributes,
              );
            }
          }
        }
      }

      // Изображение / другой embed.
      else if (insert is Map) {
        if (insert.containsKey('image')) {
          final imageSource =
              _escapeHtml(
            insert['image'].toString(),
          );

          html.write(
            '<p><img src="$imageSource" alt=""></p>',
          );
        }
      }
    }

    // Последний текст, если Delta не закончилась
    // переносом строки.
    if (currentText.isNotEmpty) {
      final formatted =
          _applyInlineAttributes(
        currentText,
        null,
      );

      html.write('<p>$formatted</p>');
    }

    html.write('''
</body>
</html>
''');

    return html.toString();
  }

  // ==========================================================
  // SAVE HTML
  // ==========================================================

Future<void> _saveToHtmlFile() async {
    try {
      FocusScope.of(context).unfocus();

      // ТЕСТОВЫЙ HTML.
      // Здесь специально НЕ используется редактор.
      const htmlContent = '''
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<title>Тест HTML</title>
</head>
<body>

<h1>ТЕСТ HTML</h1>

<p>Если ты видишь этот текст в браузере,
значит сохранение HTML работает правильно.</p>

<p>Вторая строка теста.</p>

</body>
</html>
''';

      final tempDirectory = Directory.systemTemp;

      final tempFile = File(
        '${tempDirectory.path}/test_html.html',
      );

      await tempFile.writeAsString(
        htmlContent,
        encoding: utf8,
        flush: true,
      );

      final savedPath =
          await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: tempFile.path,
        ),
      );

      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      if (!mounted) {
        return;
      }

      if (savedPath == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Сохранение отменено',
              ),
            ),
          );

        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Тестовый HTML сохранён',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка:\n$e',
            ),
          ),
        );
    }
  }

      // ------------------------------------------------------
      // 3. Создаём временный HTML-файл
      // ------------------------------------------------------

      final tempDirectory = Directory.systemTemp;

      tempFile = File(
        '${tempDirectory.path}/$fileName',
      );

      await tempFile!.writeAsString(
        htmlContent,
        encoding: utf8,
        flush: true,
      );

      // ------------------------------------------------------
      // 4. Проверяем, что файл реально записался
      // ------------------------------------------------------

      if (!await tempFile!.exists()) {
        throw Exception(
          'Временный HTML-файл не был создан.',
        );
      }

      final fileSize = await tempFile!.length();

      if (fileSize == 0) {
        throw Exception(
          'Временный HTML-файл имеет размер 0 байт.',
        );
      }

      // ------------------------------------------------------
      // 5. Android Save File Dialog
      // ------------------------------------------------------

      final savedPath =
          await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: tempFile!.path,
        ),
      );

      // ------------------------------------------------------
      // 6. Удаляем временный файл
      // ------------------------------------------------------

      try {
        if (await tempFile!.exists()) {
          await tempFile!.delete();
        }
      } catch (_) {}

      tempFile = null;

      if (!mounted) {
        return;
      }

      // ------------------------------------------------------
      // 7. Пользователь отменил сохранение
      // ------------------------------------------------------

      if (savedPath == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Сохранение отменено',
              ),
            ),
          );

        return;
      }

      // ------------------------------------------------------
      // 8. Успешное сохранение
      // ------------------------------------------------------

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'HTML сохранён.\nРазмер: $fileSize байт',
            ),
            duration:
                const Duration(seconds: 4),
          ),
        );
    } catch (e) {
      // ------------------------------------------------------
      // Удаляем временный файл при ошибке
      // ------------------------------------------------------

      try {
        if (tempFile != null &&
            await tempFile!.exists()) {
          await tempFile!.delete();
        }
      } catch (_) {}

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка сохранения HTML:\n$e',
            ),
            duration:
                const Duration(seconds: 5),
          ),
        );
    }
  }

  // ==========================================================
  // CLOSE EDITOR
  // ==========================================================

  Future<bool> _closeEditor() async {
    Navigator.pop(
      context,
      {
        'title':
            _titleController.text,

        'contentJson':
            jsonEncode(
          _controller!.document.toJson(),
        ),

        'category':
            _selectedCategory,
      },
    );

    return false;
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final categories =
        widget.categories
            .where((cat) => cat != 'Все')
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактор'),

        actions: [
          IconButton(
            icon: const Icon(
              Icons.save_alt,
            ),

            tooltip:
                'Сохранить как HTML',

            onPressed:
                _saveToHtmlFile,
          ),

          if (categories.isNotEmpty)
            DropdownButton<String>(
              value: categories.contains(
                _selectedCategory,
              )
                  ? _selectedCategory
                  : categories.first,

              underline:
                  const SizedBox(),

              items: categories
                  .map(
                    (category) =>
                        DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),

              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedCategory =
                      value;
                });
              },
            ),
        ],
      ),

      body: PopScope(
        canPop: false,

        onPopInvokedWithResult:
            (didPop, result) {
          if (!didPop) {
            _closeEditor();
          }
        },

        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.all(16),

              child: TextField(
                controller:
                    _titleController,

                style:
                    const TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),

                decoration:
                    const InputDecoration(
                  hintText:
                      'Заголовок',
                  border:
                      InputBorder.none,
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                ),

                child: FleatherEditor(
                  controller:
                      _controller!,

                  focusNode:
                      _focusNode,
                ),
              ),
            ),

            Material(
              elevation: 4,

              child:
                  FleatherToolbar.basic(
                controller:
                    _controller!,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller?.dispose();
    _titleController.dispose();

    super.dispose();
  }
}
