import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

void main() {
  runApp(const LocalNotesApp());
}

// ============================================================
// APP
// ============================================================

class LocalNotesApp extends StatelessWidget {
  const LocalNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мой Блокнот',
      debugShowCheckedModeBanner: false,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
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
          DateTime.now().microsecondsSinceEpoch.toString(),

      title: map['title']?.toString() ?? '',

      contentJson: map['contentJson']?.toString() ??
          '[{"insert":"\\n"}]',

      category: map['category']?.toString() ?? 'Личное',
    );
  }

  Note copy() {
    return Note(
      id: id,
      title: title,
      contentJson: contentJson,
      category: category,
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
  List<Note> _trash = [];

  List<String> _categories = [
    'Все',
    'Личное',
    'Работа',
    'Идеи',
    'Покупки',
  ];

  TabController? _tabController;

  bool _loading = true;

  static const String _notesKey = 'local_notes_clean';
  static const String _categoriesKey = 'local_categories';
  static const String _trashKey = 'local_notes_trash';

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
        prefs.getStringList(_categoriesKey);

    final notesString =
        prefs.getString(_notesKey);

    final trashString =
        prefs.getString(_trashKey);

    List<String> categories;

    if (savedCategories == null ||
        savedCategories.isEmpty) {
      categories = [
        'Все',
        'Личное',
        'Работа',
        'Идеи',
        'Покупки',
      ];
    } else {
      categories = List<String>.from(
        savedCategories,
      );

      categories.removeWhere(
        (c) => c == 'Все',
      );

      categories.insert(0, 'Все');
    }

    List<Note> notes = [];
    List<Note> trash = [];

    if (notesString != null &&
        notesString.isNotEmpty) {
      try {
        final decoded = jsonDecode(notesString);

        if (decoded is List) {
          notes = decoded
              .whereType<Map>()
              .map(
                (item) => Note.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
      } catch (_) {
        notes = [];
      }
    }

    if (trashString != null &&
        trashString.isNotEmpty) {
      try {
        final decoded = jsonDecode(trashString);

        if (decoded is List) {
          trash = decoded
              .whereType<Map>()
              .map(
                (item) => Note.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
      } catch (_) {
        trash = [];
      }
    }

    final fallbackCategory =
        categories.length > 1
            ? categories[1]
            : 'Личное';

    for (final note in notes) {
      if (!categories.contains(note.category)) {
        note.category = fallbackCategory;
      }
    }

    for (final note in trash) {
      if (!categories.contains(note.category)) {
        note.category = fallbackCategory;
      }
    }

    _createTabController(
      categories.length,
      0,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = categories;
      _notes = notes;
      _trash = trash;
      _loading = false;
    });
  }

  // ==========================================================
  // TAB CONTROLLER
  // ==========================================================

  void _createTabController(
    int length,
    int index,
  ) {
    _tabController?.dispose();

    _tabController = TabController(
      length: length,
      vsync: this,
    );

    final safeIndex =
        index.clamp(0, length - 1);

    _tabController!.index = safeIndex;

    _tabController!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _recreateTabController({
    int selectedIndex = 0,
  }) {
    _createTabController(
      _categories.length,
      selectedIndex,
    );

    setState(() {});
  }

  // ==========================================================
  // SAVE
  // ==========================================================

  Future<void> _saveData() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setStringList(
      _categoriesKey,
      _categories,
    );

    await prefs.setString(
      _notesKey,
      jsonEncode(
        _notes
            .map((note) => note.toMap())
            .toList(),
      ),
    );

    await prefs.setString(
      _trashKey,
      jsonEncode(
        _trash
            .map((note) => note.toMap())
            .toList(),
      ),
    );
  }

  // ==========================================================
  // ADD CATEGORY
  // ==========================================================

  Future<void> _addCategory() async {
    final controller =
        TextEditingController();

    final name =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('Новый раздел'),

          content:
              TextField(
            controller: controller,
            autofocus: true,
            textCapitalization:
                TextCapitalization.sentences,
            decoration:
                const InputDecoration(
              labelText: 'Название',
              hintText: 'Например: Статьи',
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Отмена'),
            ),

            FilledButton(
              onPressed: () {
                final value =
                    controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(
                    context,
                    value,
                  );
                }
              },
              child:
                  const Text('Добавить'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name == null ||
        name.trim().isEmpty) {
      return;
    }

    final newName =
        name.trim();

    if (_categories.contains(newName)) {
      _showMessage(
        'Такой раздел уже существует',
      );
      return;
    }

    final newIndex =
        _categories.length;

    setState(() {
      _categories.add(newName);
    });

    _recreateTabController(
      selectedIndex: newIndex,
    );

    await _saveData();

    _showMessage(
      'Раздел «$newName» добавлен',
    );
  }

  // ==========================================================
  // RENAME CATEGORY
  // ==========================================================

  Future<void> _renameCategory(
    String category,
  ) async {
    if (category == 'Все') {
      return;
    }

    final controller =
        TextEditingController(
      text: category,
    );

    final newName =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text(
            'Переименовать раздел',
          ),

          content:
              TextField(
            controller: controller,
            autofocus: true,
            textCapitalization:
                TextCapitalization.sentences,
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Отмена'),
            ),

            FilledButton(
              onPressed: () {
                final value =
                    controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(
                    context,
                    value,
                  );
                }
              },
              child:
                  const Text('Сохранить'),
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

    final trimmed =
        newName.trim();

    if (_categories.contains(trimmed)) {
      _showMessage(
        'Такой раздел уже существует',
      );
      return;
    }

    setState(() {
      final index =
          _categories.indexOf(category);

      if (index != -1) {
        _categories[index] =
            trimmed;
      }

      for (final note in _notes) {
        if (note.category == category) {
          note.category = trimmed;
        }
      }

      for (final note in _trash) {
        if (note.category == category) {
          note.category = trimmed;
        }
      }
    });

    final selectedIndex =
        _categories.indexOf(trimmed);

    _recreateTabController(
      selectedIndex:
          selectedIndex < 0
              ? 0
              : selectedIndex,
    );

    await _saveData();

    _showMessage(
      'Раздел переименован',
    );
  }

  // ==========================================================
  // DELETE CATEGORY
  // ==========================================================

  Future<void> _deleteCategory(
    String category,
  ) async {
    if (category == 'Все') {
      return;
    }

    final notesCount =
        _notes
            .where(
              (n) => n.category == category,
            )
            .length;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text(
            'Удалить раздел?',
          ),

          content:
              Text(
            notesCount == 0
                ? 'Раздел «$category» пуст.'
                : 'В разделе «$category» находится '
                    '$notesCount заметок.\n\n'
                    'Заметки будут перенесены '
                    'в первый доступный раздел.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text('Отмена'),
            ),

            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
                  const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    String targetCategory =
        'Личное';

    for (final c in _categories) {
      if (c != 'Все' &&
          c != category) {
        targetCategory = c;
        break;
      }
    }

    final currentIndex =
        _tabController?.index ?? 0;

    setState(() {
      _categories.remove(category);

      for (final note in _notes) {
        if (note.category == category) {
          note.category =
              targetCategory;
        }
      }

      for (final note in _trash) {
        if (note.category == category) {
          note.category =
              targetCategory;
        }
      }
    });

    final safeIndex =
        currentIndex.clamp(
      0,
      _categories.length - 1,
    );

    _recreateTabController(
      selectedIndex: safeIndex,
    );

    await _saveData();

    _showMessage(
      'Раздел удалён',
    );
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
          builder:
              (context, modalSetState) {
            return SafeArea(
              child:
                  SizedBox(
                height:
                    MediaQuery.of(context)
                            .size
                            .height *
                        0.75,

                child:
                    Column(
                  children: [
                    const Padding(
                      padding:
                          EdgeInsets.all(16),
                      child:
                          Text(
                        'Разделы',
                        style:
                            TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    const Text(
                      'Удерживайте раздел '
                      'и перетащите его',
                      style:
                          TextStyle(
                        color:
                            Colors.white54,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Expanded(
                      child:
                          ReorderableListView.builder(
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),

                        itemCount:
                            _categories.length - 1,

                        onReorder:
                            (
                          oldIndex,
                          newIndex,
                        ) async {
                          if (oldIndex <
                              newIndex) {
                            newIndex--;
                          }

                          final fromIndex =
                              oldIndex + 1;

                          final toIndex =
                              newIndex + 1;

                          final selectedIndex =
                              _tabController
                                      ?.index ??
                                  0;

                          final selectedCategory =
                              _categories[
                                  selectedIndex];

                          setState(() {
                            final item =
                                _categories
                                    .removeAt(
                              fromIndex,
                            );

                            _categories.insert(
                              toIndex,
                              item,
                            );
                          });

                          modalSetState(() {});

                          _recreateTabController(
                            selectedIndex:
                                _categories.indexOf(
                              selectedCategory,
                            ),
                          );

                          await _saveData();
                        },

                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          final category =
                              _categories[
                                  index + 1];

                          return Card(
                            key:
                                ValueKey(
                              'category_$category',
                            ),

                            child:
                                ListTile(
                              leading:
                                  const Icon(
                                Icons
                                    .drag_handle,
                              ),

                              title:
                                  Text(
                                category,
                              ),

                              trailing:
                                  Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip:
                                        'Переименовать',
                                    icon:
                                        const Icon(
                                      Icons.edit,
                                    ),
                                    onPressed:
                                        () async {
                                      Navigator.pop(
                                        context,
                                      );

                                      await _renameCategory(
                                        category,
                                      );
                                    },
                                  ),

                                  IconButton(
                                    tooltip:
                                        'Удалить',
                                    icon:
                                        const Icon(
                                      Icons.delete_outline,
                                      color:
                                          Colors.redAccent,
                                    ),
                                    onPressed:
                                        () async {
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
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      child:
                          SizedBox(
                        width:
                            double.infinity,
                        child:
                            FilledButton.icon(
                          onPressed:
                              () async {
                            Navigator.pop(
                              context,
                            );

                            await _addCategory();
                          },
                          icon:
                              const Icon(
                            Icons.add,
                          ),
                          label:
                              const Text(
                            'Добавить раздел',
                          ),
                        ),
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
  // ADD NOTE
  // ==========================================================

  Future<void> _addNote() async {
    final currentIndex =
        _tabController?.index ?? 0;

    final defaultCategory =
        currentIndex > 0 &&
                currentIndex <
                    _categories.length
            ? _categories[
                currentIndex]
            : (_categories.length > 1
                ? _categories[1]
                : 'Личное');

    final result =
        await Navigator.push<
            Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditorScreen(
          categories:
              _categories,
          initialCategory:
              defaultCategory,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    final note = Note(
      id:
          DateTime.now()
              .microsecondsSinceEpoch
              .toString(),

      title:
          result['title']
                  ?.toString() ??
              '',

      contentJson:
          result['contentJson']
                  ?.toString() ??
              '[{"insert":"\\n"}]',

      category:
          result['category']
                  ?.toString() ??
              defaultCategory,
    );

    setState(() {
      _notes.add(note);
    });

    await _saveData();
  }

  // ==========================================================
  // EDIT NOTE
  // ==========================================================

  Future<void> _editNote(
    Note note,
  ) async {
    final result =
        await Navigator.push<
            Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditorScreen(
          note: note,
          categories:
              _categories,
          initialCategory:
              note.category,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    final index =
        _notes.indexWhere(
      (n) => n.id == note.id,
    );

    if (index == -1) {
      return;
    }

    setState(() {
      _notes[index] = Note(
        id: note.id,

        title:
            result['title']
                    ?.toString() ??
                '',

        contentJson:
            result['contentJson']
                    ?.toString() ??
                '[{"insert":"\\n"}]',

        category:
            result['category']
                    ?.toString() ??
                note.category,
      );
    });

    await _saveData();
  }

  // ==========================================================
  // DELETE NOTE
  // ==========================================================

  Future<void> _deleteNote(
    Note note,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text(
            'Удалить заметку?',
          ),

          content:
              Text(
            note.title.isEmpty
                ? 'Без названия'
                : note.title,
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text('Отмена'),
            ),

            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
                  const Text('В корзину'),
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

      _trash.removeWhere(
        (n) => n.id == note.id,
      );

      _trash.insert(
        0,
        note.copy(),
      );
    });

    await _saveData();

    _showMessage(
      'Заметка перемещена в корзину',
    );
  }

  // ==========================================================
  // RESTORE
  // ==========================================================

  Future<void> _restoreFromTrash(
    Note note,
  ) async {
    setState(() {
      _trash.removeWhere(
        (n) => n.id == note.id,
      );

      if (!_categories.contains(
        note.category,
      )) {
        note.category =
            _categories.length > 1
                ? _categories[1]
                : 'Личное';
      }

      _notes.add(
        note.copy(),
      );
    });

    await _saveData();

    _showMessage(
      'Заметка восстановлена',
    );
  }

  // ==========================================================
  // DELETE FOREVER
  // ==========================================================

  Future<void> _deleteForever(
    Note note,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text(
            'Удалить навсегда?',
          ),

          content:
              Text(
            note.title.isEmpty
                ? 'Без названия'
                : note.title,
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text('Отмена'),
            ),

            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
                  const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _trash.removeWhere(
        (n) => n.id == note.id,
      );
    });

    await _saveData();
  }

  // ==========================================================
  // TRASH
  // ==========================================================

  Future<void> _showTrash() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child:
              SizedBox(
            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.8,

            child:
                Column(
              children: [
                const Padding(
                  padding:
                      EdgeInsets.all(16),
                  child:
                      Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Корзина',
                        style:
                            TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_trash.isEmpty)
                  const Expanded(
                    child:
                        Center(
                      child:
                          Text(
                        'Корзина пуста',
                      ),
                    ),
                  )
                else
                  Expanded(
                    child:
                        ListView.builder(
                      itemCount:
                          _trash.length,

                      itemBuilder:
                          (
                        context,
                        index,
                      ) {
                        final note =
                            _trash[index];

                        return ListTile(
                          leading:
                              const Icon(
                            Icons
                                .description_outlined,
                          ),

                          title:
                              Text(
                            note.title.isEmpty
                                ? 'Без названия'
                                : note.title,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),

                          subtitle:
                              Text(
                            note.category,
                          ),

                          trailing:
                              Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip:
                                    'Восстановить',
                                icon:
                                    const Icon(
                                  Icons.restore,
                                ),
                                onPressed:
                                    () async {
                                  await _restoreFromTrash(
                                    note,
                                  );

                                  if (context
                                      .mounted) {
                                    Navigator.pop(
                                      context,
                                    );
                                  }
                                },
                              ),

                              IconButton(
                                tooltip:
                                    'Удалить навсегда',
                                icon:
                                    const Icon(
                                  Icons.delete_forever,
                                  color:
                                      Colors.redAccent,
                                ),
                                onPressed:
                                    () async {
                                  await _deleteForever(
                                    note,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                if (_trash.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    child:
                        SizedBox(
                      width:
                          double.infinity,
                      child:
                          OutlinedButton.icon(
                        icon:
                            const Icon(
                          Icons
                              .delete_forever,
                        ),
                        label:
                            const Text(
                          'Очистить корзину',
                        ),
                        onPressed:
                            () async {
                          final confirmed =
                              await showDialog<
                                  bool>(
                            context:
                                context,
                            builder:
                                (context) {
                              return AlertDialog(
                                title:
                                    const Text(
                                  'Очистить корзину?',
                                ),
                                content:
                                    const Text(
                                  'Все заметки в корзине '
                                  'будут удалены навсегда.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () {
                                      Navigator.pop(
                                        context,
                                        false,
                                      );
                                    },
                                    child:
                                        const Text(
                                      'Отмена',
                                    ),
                                  ),
                                  FilledButton(
                                    style:
                                        FilledButton.styleFrom(
                                      backgroundColor:
                                          Colors.red,
                                    ),
                                    onPressed:
                                        () {
                                      Navigator.pop(
                                        context,
                                        true,
                                      );
                                    },
                                    child:
                                        const Text(
                                      'Удалить',
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed ==
                              true) {
                            setState(() {
                              _trash.clear();
                            });

                            await _saveData();

                            if (context
                                .mounted) {
                              Navigator.pop(
                                context,
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // REORDER NOTES
  // ==========================================================

  Future<void> _reorderNotes(
    String category,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) {
      return;
    }

    final visibleNotes =
        category == 'Все'
            ? List<Note>.from(_notes)
            : _notes
                .where(
                  (n) =>
                      n.category ==
                      category,
                )
                .toList();

    if (oldIndex < 0 ||
        oldIndex >= visibleNotes.length) {
      return;
    }

    if (newIndex < 0 ||
        newIndex >= visibleNotes.length) {
      newIndex =
          visibleNotes.length - 1;
    }

    final moved =
        visibleNotes.removeAt(
      oldIndex,
    );

    visibleNotes.insert(
      newIndex,
      moved,
    );

    setState(() {
      if (category == 'Все') {
        _notes = visibleNotes;
      } else {
        int visibleIndex = 0;

        for (int i = 0;
            i < _notes.length;
            i++) {
          if (_notes[i].category ==
              category) {
            _notes[i] =
                visibleNotes[
                    visibleIndex];
            visibleIndex++;
          }
        }
      }
    });

    await _saveData();
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(
    String text,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(text),
          duration:
              const Duration(
            seconds: 2,
          ),
        ),
      );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading ||
        _tabController == null) {
      return const Scaffold(
        body:
            Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Мой Блокнот',
        ),

        actions: [
          IconButton(
            tooltip:
                'Корзина',
            icon:
                const Icon(
              Icons.delete_outline,
            ),
            onPressed:
                _showTrash,
          ),

          IconButton(
            tooltip:
                'Разделы',
            icon:
                const Icon(
              Icons.folder_open,
            ),
            onPressed:
                _manageCategories,
          ),
        ],

        bottom:
            TabBar(
          controller:
              _tabController,
          isScrollable:
              true,
          tabs:
              _categories
                  .map(
                    (category) =>
                        Tab(
                      text:
                          category,
                    ),
                  )
                  .toList(),
        ),
      ),

      body:
          TabBarView(
        controller:
            _tabController,

        children:
            _categories.map(
          (category) {
            final filteredNotes =
                category == 'Все'
                    ? List<Note>.from(
                        _notes,
                      )
                    : _notes
                        .where(
                          (n) =>
                              n.category ==
                              category,
                        )
                        .toList();

            if (filteredNotes
                .isEmpty) {
              return Center(
                child:
                    Text(
                  'Здесь пока пусто',
                  style:
                      TextStyle(
                    color:
                        Colors.white
                            .withOpacity(
                      0.54,
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding:
                  const EdgeInsets.all(
                8,
              ),

              child:
                  ReorderableGridView.builder(
                padding:
                    const EdgeInsets.only(
                  bottom: 90,
                ),

                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      2,
                  crossAxisSpacing:
                      8,
                  mainAxisSpacing:
                      8,
                  childAspectRatio:
                      1.1,
                ),

                itemCount:
                    filteredNotes.length,

                dragStartDelay:
                    const Duration(
                  milliseconds:
                      450,
                ),

                onReorder:
                    (
                  oldIndex,
                  newIndex,
                ) {
                  _reorderNotes(
                    category,
                    oldIndex,
                    newIndex,
                  );
                },

                itemBuilder:
                    (
                  context,
                  index,
                ) {
                  final note =
                      filteredNotes[
                          index];

                  return Card(
                    key:
                        ValueKey(
                      note.id,
                    ),

                    child:
                        InkWell(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),

                      onTap: () =>
                          _editNote(
                        note,
                      ),

                      child:
                          Padding(
                        padding:
                            const EdgeInsets
                                .all(
                          12,
                        ),

                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [
                                Expanded(
                                  child:
                                      Text(
                                    note.title
                                            .isEmpty
                                        ? 'Без названия'
                                        : note.title,

                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize:
                                          16,
                                    ),

                                    maxLines:
                                        2,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                  ),
                                ),

                                PopupMenuButton<
                                    String>(
                                  padding:
                                      EdgeInsets.zero,

                                  icon:
                                      const Icon(
                                    Icons.more_vert,
                                    size:
                                        20,
                                  ),

                                  onSelected:
                                      (
                                    value,
                                  ) async {
                                    if (value ==
                                        'delete') {
                                      await _deleteNote(
                                        note,
                                      );
                                    }
                                  },

                                  itemBuilder:
                                      (
                                    context,
                                  ) =>
                                      const [
                                    PopupMenuItem(
                                      value:
                                          'delete',
                                      child:
                                          Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            color:
                                                Colors.red,
                                          ),
                                          SizedBox(
                                            width:
                                                8,
                                          ),
                                          Text(
                                            'В корзину',
                                          ),
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
                                horizontal:
                                    6,
                                vertical:
                                    2,
                              ),

                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.white10,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  4,
                                ),
                              ),

                              child:
                                  Text(
                                note.category,
                                style:
                                    const TextStyle(
                                  fontSize:
                                      10,
                                  color:
                                      Colors.amber,
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
        onPressed:
            _addNote,
        child:
            const Icon(
          Icons.add,
        ),
      ),
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

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

// ============================================================
// EDITOR STATE
// ============================================================

class _EditorScreenState
    extends State<EditorScreen> {
  late QuillController _controller;

  final TextEditingController
      _titleController =
      TextEditingController();

  final FocusNode _focusNode =
      FocusNode();

  final ScrollController
      _scrollController =
      ScrollController();

  late String _selectedCategory;

  bool _closing = false;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _selectedCategory =
        _getInitialCategory();

    _controller =
        _createController();
  }

  // ==========================================================
  // CATEGORY
  // ==========================================================

  String _getInitialCategory() {
    if (widget.note != null) {
      _titleController.text =
          widget.note!.title;

      if (widget.categories
          .contains(
        widget.note!.category,
      )) {
        return widget.note!.category;
      }
    }

    final available =
        widget.categories
            .where(
              (c) => c != 'Все',
            )
            .toList();

    if (widget.initialCategory !=
            null &&
        available.contains(
          widget.initialCategory,
        )) {
      return widget.initialCategory!;
    }

    if (available.contains(
      'Личное',
    )) {
      return 'Личное';
    }

    if (available.isNotEmpty) {
      return available.first;
    }

    return 'Личное';
  }

  // ==========================================================
  // CONTROLLER
  // ==========================================================

  QuillController _createController() {
    if (widget.note != null &&
        widget.note!.contentJson
            .trim()
            .isNotEmpty) {
      try {
        final decoded =
            jsonDecode(
          widget.note!.contentJson,
        );

        if (decoded is List) {
          final document =
              Document.fromJson(
            decoded,
          );

          return QuillController(
            document: document,

            selection:
                TextSelection.collapsed(
              offset:
                  document.length - 1,
            ),

            // КЛЮЧЕВОЙ ПАРАМЕТР.
            //
            // При Enter стиль текущего текста
            // сохраняется для новой строки.
            keepStyleOnNewLine: true,
          );
        }
      } catch (_) {
        // Если старый JSON повреждён,
        // создаём пустой документ.
      }
    }

    return QuillController(
      document:
          Document(),
      selection:
          const TextSelection.collapsed(
        offset: 0,
      ),
      keepStyleOnNewLine: true,
    );
  }

  // ==========================================================
  // SAVE CONTENT
  // ==========================================================

  String _getContentJson() {
    final delta =
        _controller.document
            .toDelta()
            .toJson();

    return jsonEncode(
      delta,
    );
  }

  // ==========================================================
  // SAVE
  // ==========================================================

  void _saveNoteAndClose() {
    if (_closing) {
      return;
    }

    _closing = true;

    final result =
        <String, dynamic>{
      'title':
          _titleController.text
              .trim(),

      'contentJson':
          _getContentJson(),

      'category':
          _selectedCategory,
    };

    Navigator.pop(
      context,
      result,
    );
  }

  // ==========================================================
  // EXPORT TXT
  // ==========================================================

  Future<void> _saveToDevice() async {
    try {
      final title =
          _titleController.text
              .trim();

      final plainText =
          _controller.document
              .toPlainText();

      final safeTitle =
          _safeFileName(
        title.isEmpty
            ? 'untitled_note'
            : title,
      );

      final fileName =
          '$safeTitle.txt';

      final tempDirectory =
          Directory.systemTemp;

      final tempFile = File(
        '${tempDirectory.path}/'
        '${DateTime.now().microsecondsSinceEpoch}_'
        '$fileName',
      );

      await tempFile.writeAsString(
        plainText,
        encoding: utf8,
        flush: true,
      );

      if (!await tempFile.exists()) {
        throw Exception(
          'Временный TXT-файл не создан.',
        );
      }

      final savedPath =
          await FlutterFileDialog
              .saveFile(
        params:
            SaveFileDialogParams(
          sourceFilePath:
              tempFile.path,
          fileName:
              fileName,
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

      if (savedPath != null &&
          savedPath.isNotEmpty) {
        _showMessage(
          'TXT-файл сохранён',
        );
      } else {
        _showMessage(
          'Сохранение отменено',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Ошибка сохранения TXT:\n$e',
      );
    }
  }

  // ==========================================================
  // SAFE FILE NAME
  // ==========================================================

  String _safeFileName(
    String value,
  ) {
    var result =
        value.trim();

    if (result.isEmpty) {
      result =
          'untitled_note';
    }

    result =
        result.replaceAll(
      RegExp(
        r'[\\/:*?"<>|]',
      ),
      '_',
    );

    return result;
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(
    String text,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(text),
          duration:
              const Duration(
            seconds: 3,
          ),
        ),
      );
  }

  // ==========================================================
  // TOOLBAR
  // ==========================================================

  Widget _buildToolbar() {
    return QuillSimpleToolbar(
      controller:
          _controller,

      config:
          const QuillSimpleToolbarConfig(
        multiRowsDisplay:
            false,
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return PopScope<
        Map<String, dynamic>?>(
      canPop: false,

      onPopInvokedWithResult:
          (
        didPop,
        result,
      ) {
        if (didPop) {
          return;
        }

        _saveNoteAndClose();
      },

      child:
          Scaffold(
        appBar:
            AppBar(
          title:
              TextField(
            controller:
                _titleController,

            style:
                const TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),

            decoration:
                const InputDecoration(
              hintText:
                  'Название заметки',
              border:
                  InputBorder.none,
            ),

            textInputAction:
                TextInputAction.done,
          ),

          actions: [
            IconButton(
              tooltip:
                  'Сохранить как TXT',

              icon:
                  const Icon(
                Icons.file_download_outlined,
              ),

              onPressed:
                  _saveToDevice,
            ),

            IconButton(
              tooltip:
                  'Сохранить',

              icon:
                  const Icon(
                Icons.save,
              ),

              onPressed:
                  _saveNoteAndClose,
            ),
          ],
        ),

        body:
            SafeArea(
          child:
              Column(
            children: [
              // =================================================
              // CATEGORY
              // =================================================

              Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  12,
                  8,
                  12,
                  4,
                ),

                child:
                    Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 20,
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    const Text(
                      'Раздел:',
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child:
                          DropdownButtonHideUnderline(
                        child:
                            DropdownButton<
                                String>(
                          value:
                              widget.categories
                                      .contains(
                                    _selectedCategory,
                                  )
                                  ? _selectedCategory
                                  : null,

                          isExpanded:
                              true,

                          items:
                              widget.categories
                                  .where(
                                    (category) =>
                                        category !=
                                        'Все',
                                  )
                                  .map(
                                    (
                                      category,
                                    ) =>
                                        DropdownMenuItem<
                                            String>(
                                      value:
                                          category,
                                      child:
                                          Text(
                                        category,
                                      ),
                                    ),
                                  )
                                  .toList(),

                          onChanged:
                              (
                            value,
                          ) {
                            if (value ==
                                null) {
                              return;
                            }

                            setState(() {
                              _selectedCategory =
                                  value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(
                height: 1,
              ),

              // =================================================
              // TOOLBAR
              // =================================================

              SingleChildScrollView(
                scrollDirection:
                    Axis.horizontal,

                child:
                    _buildToolbar(),
              ),

              const Divider(
                height: 1,
              ),

              // =================================================
              // EDITOR
              // =================================================

              Expanded(
                child:
                    Padding(
                  padding:
                      const EdgeInsets.all(
                    8,
                  ),

                  child:
                      QuillEditor(
                    controller:
                        _controller,

                    focusNode:
                        _focusNode,

                    scrollController:
                        _scrollController,

                    config:
                        const QuillEditorConfig(
                      padding:
                          EdgeInsets.all(
                        12,
                      ),

                      expands:
                          true,

                      autoFocus:
                          false,

                      showCursor:
                          true,

                      scrollable:
                          true,

                      enableInteractiveSelection:
                          true,

                      enableSelectionToolbar:
                          true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _titleController.dispose();

    super.dispose();
  }
}
