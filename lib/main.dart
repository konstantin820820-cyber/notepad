import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fleather/fleather.dart';
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
        scaffoldBackgroundColor:
            const Color(0xFF121212),
        cardTheme: CardThemeData(
          elevation: 1,
          margin: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 5,
          ),
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
          DateTime.now()
              .microsecondsSinceEpoch
              .toString(),

      title: map['title']?.toString() ?? '',

      contentJson:
          map['contentJson']?.toString() ??
              '[{"insert":"\\n"}]',

      category:
          map['category']?.toString() ??
              'Личное',
    );
  }
}

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen>
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

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ==========================================================
  // LOAD DATA
  // ==========================================================

  Future<void> _loadData() async {
    final prefs =
        await SharedPreferences.getInstance();

    final savedCategories =
        prefs.getStringList(
      'local_categories',
    );

    final notesString =
        prefs.getString(
      'local_notes_clean',
    );

    final trashString =
        prefs.getString(
      'local_notes_trash',
    );

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
      categories =
          List<String>.from(
        savedCategories,
      );

      categories.removeWhere(
        (c) => c == 'Все',
      );

      categories.insert(
        0,
        'Все',
      );
    }

    List<Note> notes = [];

    if (notesString != null &&
        notesString.isNotEmpty) {
      try {
        final decoded =
            jsonDecode(notesString);

        if (decoded is List) {
          notes = decoded
              .map(
                (item) => Note.fromMap(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList();
        }
      } catch (_) {
        notes = [];
      }
    }

    List<Note> trash = [];

    if (trashString != null &&
        trashString.isNotEmpty) {
      try {
        final decoded =
            jsonDecode(trashString);

        if (decoded is List) {
          trash = decoded
              .map(
                (item) => Note.fromMap(
                  Map<String, dynamic>.from(
                    item,
                  ),
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
      if (!categories.contains(
        note.category,
      )) {
        note.category =
            fallbackCategory;
      }
    }

    _tabController?.dispose();

    _tabController =
        TabController(
      length: categories.length,
      vsync: this,
    );

    _tabController!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

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
  // SAVE DATA
  // ==========================================================

  Future<void> _saveData() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setStringList(
      'local_categories',
      _categories,
    );

    await prefs.setString(
      'local_notes_clean',
      jsonEncode(
        _notes
            .map(
              (note) => note.toMap(),
            )
            .toList(),
      ),
    );

    await prefs.setString(
      'local_notes_trash',
      jsonEncode(
        _trash
            .map(
              (note) => note.toMap(),
            )
            .toList(),
      ),
    );
  }

  // ==========================================================
  // RECREATE TAB CONTROLLER
  // ==========================================================

  void _recreateTabController({
    int selectedIndex = 0,
  }) {
    _tabController?.dispose();

    _tabController =
        TabController(
      length: _categories.length,
      vsync: this,
    );

    final safeIndex =
        selectedIndex.clamp(
      0,
      _categories.length - 1,
    );

    _tabController!.index =
        safeIndex;

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
    final controller =
        TextEditingController();

    final name =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text(
            'Новый раздел',
          ),

          content:
              TextField(
            controller:
                controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              labelText:
                  'Название',
              hintText:
                  'Например: Статьи',
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text(
                'Отмена',
              ),
            ),

            FilledButton(
              onPressed: () {
                final value =
                    controller.text
                        .trim();

                if (value.isNotEmpty) {
                  Navigator.pop(
                    context,
                    value,
                  );
                }
              },
              child:
                  const Text(
                'Добавить',
              ),
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

    if (_categories.contains(
      newName,
    )) {
      _showMessage(
        'Такой раздел уже существует',
      );
      return;
    }

    setState(() {
      _categories.add(
        newName,
      );
    });

    _recreateTabController(
      selectedIndex:
          _categories.length - 1,
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
            controller:
                controller,
            autofocus: true,
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text(
                'Отмена',
              ),
            ),

            FilledButton(
              onPressed: () {
                final value =
                    controller.text
                        .trim();

                if (value.isNotEmpty) {
                  Navigator.pop(
                    context,
                    value,
                  );
                }
              },
              child:
                  const Text(
                'Сохранить',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newName == null ||
        newName.trim().isEmpty ||
        newName.trim() ==
            category) {
      return;
    }

    final trimmed =
        newName.trim();

    if (_categories.contains(
      trimmed,
    )) {
      _showMessage(
        'Такой раздел уже существует',
      );
      return;
    }

    setState(() {
      final index =
          _categories.indexOf(
        category,
      );

      if (index != -1) {
        _categories[index] =
            trimmed;
      }

      for (final note
          in _notes) {
        if (note.category ==
            category) {
          note.category =
              trimmed;
        }
      }
    });

    final selectedIndex =
        _categories.indexOf(
      trimmed,
    );

    _recreateTabController(
      selectedIndex:
          selectedIndex,
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
              (n) =>
                  n.category ==
                  category,
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
              onPressed: () {
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

    if (confirmed != true) {
      return;
    }

    String targetCategory =
        'Личное';

    for (final c
        in _categories) {
      if (c != 'Все' &&
          c != category) {
        targetCategory = c;
        break;
      }
    }

    setState(() {
      _categories.remove(
        category,
      );

      for (final note
          in _notes) {
        if (note.category ==
            category) {
          note.category =
              targetCategory;
        }
      }
    });

    final selectedIndex =
        (_tabController?.index ??
                0)
            .clamp(
      0,
      _categories.length - 1,
    );

    _recreateTabController(
      selectedIndex:
          selectedIndex,
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
                    MediaQuery.of(
                          context,
                        ).size.height *
                        0.75,

                child:
                    Column(
                  children: [
                    const Padding(
                      padding:
                          EdgeInsets.all(
                        16,
                      ),
                      child:
                          Text(
                        'Разделы',
                        style:
                            TextStyle(
                          fontSize:
                              22,
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
                          ReorderableListView
                              .builder(
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),

                        itemCount:
                            _categories
                                    .length -
                                1,

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

                          final selectedCategory =
                              _categories[
                                  (_tabController
                                              ?.index ??
                                          0)
                                      .clamp(
                                0,
                                _categories.length -
                                    1,
                              )];

                          setState(() {
                            final item =
                                _categories
                                    .removeAt(
                              fromIndex,
                            );

                            _categories
                                .insert(
                              toIndex,
                              item,
                            );
                          });

                          modalSetState(
                            () {},
                          );

                          _recreateTabController(
                            selectedIndex:
                                _categories
                                    .indexOf(
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
  // REORDER NOTES
  // ==========================================================

  Future<void> _reorderNotes(
    String category,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex ==
        newIndex) {
      return;
    }

    final visibleNotes =
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

    if (oldIndex < 0 ||
        oldIndex >=
            visibleNotes.length) {
      return;
    }

    if (newIndex < 0 ||
        newIndex >=
            visibleNotes.length) {
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
        _notes =
            visibleNotes;
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
  // DELETE NOTE TO TRASH
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
            'Переместить в корзину?',
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
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
                  const Text(
                'В корзину',
              ),
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

      _trash.insert(
        0,
        note,
      );
    });

    await _saveData();

    _showMessage(
      'Заметка перемещена в корзину',
    );
  }

  // ==========================================================
  // TRASH
  // ==========================================================

  Future<void> _openTrash() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder:
              (
            context,
            modalSetState,
          ) {
            return SafeArea(
              child:
                  SizedBox(
                height:
                    MediaQuery.of(
                          context,
                        ).size.height *
                        0.8,

                child:
                    Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      child:
                          Row(
                        children: [
                          const Icon(
                            Icons.delete_outline,
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          const Expanded(
                            child:
                                Text(
                              'Корзина',
                              style:
                                  TextStyle(
                                fontSize:
                                    22,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),

                          if (_trash
                              .isNotEmpty)
                            TextButton(
                              onPressed:
                                  () async {
                                final confirmed =
                                    await showDialog<bool>(
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
                                        'Все заметки из корзины будут удалены окончательно.',
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
                                            'Удалить всё',
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

                                  modalSetState(
                                    () {},
                                  );

                                  await _saveData();
                                }
                              },
                              child:
                                  const Text(
                                'Очистить',
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Divider(
                      height: 1,
                    ),

                    Expanded(
                      child:
                          _trash.isEmpty
                              ? const Center(
                                  child:
                                      Text(
                                    'Корзина пуста',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.white54,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.all(
                                    8,
                                  ),
                                  itemCount:
                                      _trash.length,
                                  itemBuilder:
                                      (
                                    context,
                                    index,
                                  ) {
                                    final note =
                                        _trash[index];

                                    return Card(
                                      child:
                                          ListTile(
                                        leading:
                                            const Icon(
                                          Icons.note_outlined,
                                        ),

                                        title:
                                            Text(
                                          note.title.isEmpty
                                              ? 'Без названия'
                                              : note.title,
                                          maxLines:
                                              1,
                                          overflow:
                                              TextOverflow.ellipsis,
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
                                                final restored =
                                                    _trash.removeAt(
                                                  index,
                                                );

                                                if (!_categories.contains(
                                                  restored.category,
                                                )) {
                                                  restored.category =
                                                      _categories.length >
                                                              1
                                                          ? _categories[1]
                                                          : 'Личное';
                                                }

                                                setState(() {
                                                  _notes.insert(
                                                    0,
                                                    restored,
                                                  );
                                                });

                                                modalSetState(
                                                  () {},
                                                );

                                                await _saveData();

                                                _showMessage(
                                                  'Заметка восстановлена',
                                                );
                                              },
                                            ),

                                            IconButton(
                                              tooltip:
                                                  'Удалить окончательно',
                                              icon:
                                                  const Icon(
                                                Icons.delete_forever,
                                                color:
                                                    Colors.redAccent,
                                              ),
                                              onPressed:
                                                  () async {
                                                final confirmed =
                                                    await showDialog<bool>(
                                                  context:
                                                      context,
                                                  builder:
                                                      (context) {
                                                    return AlertDialog(
                                                      title:
                                                          const Text(
                                                        'Удалить окончательно?',
                                                      ),
                                                      content:
                                                          const Text(
                                                        'Эту заметку уже нельзя будет восстановить.',
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
                                                    _trash.removeAt(
                                                      index,
                                                    );
                                                  });

                                                  modalSetState(
                                                    () {},
                                                  );

                                                  await _saveData();
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
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
  // EDIT NOTE
  // ==========================================================

  Future<void> _editNote(
    Note note,
  ) async {
    final result =
        await Navigator.push(
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

    setState(() {
      final index =
          _notes.indexWhere(
        (n) => n.id == note.id,
      );

      if (index != -1) {
        _notes[index] =
            Note(
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
      }
    });

    await _saveData();
  }

  // ==========================================================
  // ADD NOTE
  // ==========================================================

  Future<void> _addNote() async {
    final currentIndex =
        _tabController?.index ??
            0;

    final defaultCategory =
        currentIndex > 0 &&
                currentIndex <
                    _categories.length
            ? _categories[
                currentIndex]
            : (_categories.length >
                    1
                ? _categories[1]
                : 'Личное');

    final result =
        await Navigator.push(
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

    setState(() {
      _notes.add(
        Note(
          id:
              result['id']
                      ?.toString() ??
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
        ),
      );
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

    ScaffoldMessenger.of(
      context,
    )
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
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
      appBar:
          AppBar(
        title:
            const Text(
          'Мой Блокнот',
        ),

        actions: [
          IconButton(
            tooltip:
                'Корзина',
            icon:
                Badge(
              isLabelVisible:
                  _trash.isNotEmpty,
              label:
                  Text(
                '${_trash.length}',
              ),
              child:
                  const Icon(
                Icons
                    .delete_outline,
              ),
            ),
            onPressed:
                _openTrash,
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
            _tabController!,

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
                    Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons
                          .note_alt_outlined,
                      size:
                          54,
                      color:
                          Colors.white
                              .withOpacity(
                        0.20,
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
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
                  ],
                ),
              );
            }

            return ListView.builder(
              padding:
                  const EdgeInsets.only(
                top: 8,
                bottom: 90,
              ),

              itemCount:
                  filteredNotes.length,

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
                              .fromLTRB(
                        16,
                        14,
                        8,
                        14,
                      ),

                      child:
                          Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [
                          Expanded(
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [
                                Text(
                                  note.title.isEmpty
                                      ? 'Без названия'
                                      : note.title,

                                  style:
                                      const TextStyle(
                                    fontSize:
                                        17,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),

                                  maxLines:
                                      2,

                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                ),

                                const SizedBox(
                                  height:
                                      8,
                                ),

                                _NotePreview(
                                  contentJson:
                                      note.contentJson,
                                ),

                                const SizedBox(
                                  height:
                                      10,
                                ),

                                Text(
                                  note.category,
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        11,
                                    color:
                                        Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          PopupMenuButton<
                              String>(
                            icon:
                                const Icon(
                              Icons
                                  .more_vert,
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
                                      Icons
                                          .delete_outline,
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
                    ),
                  ),
                );
              },
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
// NOTE PREVIEW
// ============================================================

class _NotePreview
    extends StatelessWidget {
  final String contentJson;

  const _NotePreview({
    required this.contentJson,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    String text = '';

    try {
      final decoded =
          jsonDecode(
        contentJson,
      );

      if (decoded is List) {
        final document =
            ParchmentDocument.fromJson(
          decoded,
        );

        text =
            document.toPlainText();
      }
    } catch (_) {
      text = '';
    }

    text = text.trim();

    if (text.isEmpty) {
      return const Text(
        'Пустая заметка',
        style:
            TextStyle(
          color:
              Colors.white38,
        ),
      );
    }

    return Text(
      text,

      style:
          const TextStyle(
        color:
            Colors.white70,
        fontSize:
            14,
        height:
            1.35,
      ),

      maxLines:
          4,

      overflow:
          TextOverflow.ellipsis,
    );
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

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _titleController =
      TextEditingController();

  final FocusNode _focusNode =
      FocusNode();

  late FleatherController _controller;

  late String _selectedCategory;

  late String _noteId;

  Timer? _autoSaveTimer;

  bool _saving = false;

  bool _hasChanges = false;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _noteId =
        widget.note?.id ??
        DateTime.now()
            .microsecondsSinceEpoch
            .toString();

    _selectedCategory =
        _getInitialCategory();

    _controller =
        _createController();

    _controller.addListener(
      _onEditorChanged,
    );

    _titleController.addListener(
      _onTitleChanged,
    );
  }

  // ==========================================================
  // INITIAL CATEGORY
  // ==========================================================

  String _getInitialCategory() {
    if (widget.note != null) {
      _titleController.text =
          widget.note!.title;

      return widget.note!.category;
    }

    final available =
        widget.categories
            .where(
              (c) => c != 'Все',
            )
            .toList();

    if (widget.initialCategory != null &&
        available.contains(
          widget.initialCategory,
        )) {
      return widget.initialCategory!;
    }

    if (available.contains('Личное')) {
      return 'Личное';
    }

    if (available.isNotEmpty) {
      return available.first;
    }

    return 'Личное';
  }

  // ==========================================================
  // CREATE CONTROLLER
  // ==========================================================

  FleatherController _createController() {
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
              ParchmentDocument.fromJson(
            decoded,
          );

          return FleatherController(
            document: document,
          );
        }
      } catch (_) {}
    }

    return FleatherController();
  }

  // ==========================================================
  // EDITOR CHANGED
  // ==========================================================

  void _onEditorChanged() {
    _hasChanges = true;
    _scheduleAutoSave();
  }

  // ==========================================================
  // TITLE CHANGED
  // ==========================================================

  void _onTitleChanged() {
    _hasChanges = true;
    _scheduleAutoSave();
  }

  // ==========================================================
  // SCHEDULE AUTOSAVE
  // ==========================================================

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();

    _autoSaveTimer = Timer(
      const Duration(
        milliseconds: 700,
      ),
      () {
        _autoSave();
      },
    );
  }

  // ==========================================================
  // BUILD CURRENT NOTE
  // ==========================================================

  Note _buildCurrentNote() {
    final contentJson =
        jsonEncode(
      _controller
          .document
          .toDelta()
          .toJson(),
    );

    return Note(
      id: _noteId,
      title:
          _titleController.text.trim(),
      contentJson:
          contentJson,
      category:
          _selectedCategory,
    );
  }

  // ==========================================================
  // AUTOSAVE
  // ==========================================================

  Future<void> _autoSave() async {
    if (!_hasChanges || _saving) {
      return;
    }

    _saving = true;

    try {
      final prefs =
          await SharedPreferences
              .getInstance();

      final note =
          _buildCurrentNote();

      final notesString =
          prefs.getString(
        'local_notes_clean',
      );

      List<Note> notes = [];

      if (notesString != null &&
          notesString.isNotEmpty) {
        try {
          final decoded =
              jsonDecode(
            notesString,
          );

          if (decoded is List) {
            notes = decoded
                .map(
                  (item) =>
                      Note.fromMap(
                    Map<String, dynamic>
                        .from(item),
                  ),
                )
                .toList();
          }
        } catch (_) {}
      }

      final index =
          notes.indexWhere(
        (n) => n.id == _noteId,
      );

      final hasRealContent =
          note.title.isNotEmpty ||
          _controller
              .document
              .toPlainText()
              .trim()
              .isNotEmpty;

      if (index == -1) {
        if (hasRealContent) {
          notes.insert(
            0,
            note,
          );
        }
      } else {
        notes[index] =
            note;
      }

      await prefs.setString(
        'local_notes_clean',
        jsonEncode(
          notes
              .map(
                (n) => n.toMap(),
              )
              .toList(),
        ),
      );

      await prefs.setStringList(
        'local_categories',
        widget.categories,
      );

      _hasChanges = false;
    } catch (_) {
      // Автосохранение не должно
      // ломать редактор.
    } finally {
      _saving = false;
    }
  }

  // ==========================================================
  // FORCE SAVE BEFORE LEAVING
  // ==========================================================

  Future<void> _saveBeforeLeaving() async {
    _autoSaveTimer?.cancel();

    if (_hasChanges) {
      await _autoSave();
    }
  }

  // ==========================================================
  // RESULT FOR HOME SCREEN
  // ==========================================================

  Map<String, dynamic> _getResult() {
    final note =
        _buildCurrentNote();

    return {
      'id': note.id,
      'title': note.title,
      'contentJson':
          note.contentJson,
      'category':
          note.category,
    };
  }

  // ==========================================================
  // SAVE NOTE BUTTON
  // ==========================================================

  Future<void> _saveNote() async {
    await _saveBeforeLeaving();

    if (!mounted) {
      return;
    }

    Navigator.pop(
      context,
      _getResult(),
    );
  }

  // ==========================================================
  // BACK / SWIPE
  // ==========================================================

  Future<bool> _handleBack() async {
    await _saveBeforeLeaving();

    if (!mounted) {
      return false;
    }

    Navigator.pop(
      context,
      _getResult(),
    );

    return false;
  }

  // ==========================================================
  // EXPORT TXT
  // ==========================================================

  Future<void> _saveToDevice() async {
    try {
      final title =
          _titleController.text.trim();

      final plainText =
          _controller
              .document
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
          'TXT сохранён на устройство',
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
  // CATEGORY
  // ==========================================================

  void _changeCategory(
    String? value,
  ) {
    if (value == null) {
      return;
    }

    setState(() {
      _selectedCategory =
          value;
    });

    _hasChanges = true;

    _scheduleAutoSave();
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

    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
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
  // TOOLBAR
  // ==========================================================

  Widget _buildToolbar() {
    return FleatherToolbar.basic(
      controller:
          _controller,

      // Оставляем обычное форматирование,
      // но убираем функции, которые могут
      // создавать визуальный отступ/списки.
      hideIndentation:
          true,

      hideListNumbers:
          true,

      hideListBullets:
          true,

      hideListChecks:
          true,

      hideCodeBlock:
          true,

      hideQuote:
          true,

      hideHeadingStyle:
          true,
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return WillPopScope(
      onWillPop:
          _handleBack,

      child: Scaffold(
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
            // ==================================================
            // TXT
            // ==================================================

            IconButton(
              tooltip:
                  'Сохранить как TXT',

              icon:
                  const Icon(
                Icons
                    .file_download_outlined,
              ),

              onPressed:
                  _saveToDevice,
            ),

            // ==================================================
            // SAVE
            // ==================================================

            IconButton(
              tooltip:
                  'Сохранить',

              icon:
                  const Icon(
                Icons.save,
              ),

              onPressed:
                  _saveNote,
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
                      Icons
                          .folder_outlined,
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
                                      .where(
                                        (c) =>
                                            c !=
                                            'Все',
                                      )
                                      .contains(
                            _selectedCategory,
                          )
                                  ? _selectedCategory
                                  : null,

                          isExpanded:
                              true,

                          items: widget
                              .categories
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
                              _changeCategory,
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
                      const EdgeInsets
                          .all(
                    8,
                  ),

                  child:
                      FleatherEditor(
                    controller:
                        _controller,

                    focusNode:
                        _focusNode,

                    padding:
                        const EdgeInsets
                            .only(
                      left: 12,
                      right: 12,
                      top: 4,
                      bottom: 12,
                    ),

                    expands:
                        true,

                    autofocus:
                        false,

                    showCursor:
                        true,

                    // Обычный Enter остаётся
                    // обычным переносом строки.
                    autocorrect:
                        true,

                    enableSuggestions:
                        true,
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
    _autoSaveTimer?.cancel();

    _controller.removeListener(
      _onEditorChanged,
    );

    _titleController.removeListener(
      _onTitleChanged,
    );

    _focusNode.dispose();

    _controller.dispose();

    _titleController.dispose();

    super.dispose();
  }
}

// ============================================================
// EDITOR STATE
// ============================================================

class _EditorScreenState
    extends State<EditorScreen> {
  final TextEditingController
      _titleController =
      TextEditingController();

  final FocusNode
      _focusNode =
      FocusNode();

  late FleatherController
      _controller;

  late String
      _selectedCategory;

  late String
      _noteId;

  Timer? _autoSaveTimer;

  bool _saving =
      false;

  bool _hasChanges =
      false;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _noteId =
        widget.note?.id ??
            DateTime.now()
                .microsecondsSinceEpoch
                .toString();

    _selectedCategory =
        _getInitialCategory();

    _controller =
        _createController();

    _controller.addListener(
      _onEditorChanged,
    );

    _titleController.addListener(
      _onTitleChanged,
    );
  }

  // ==========================================================
  // INITIAL CATEGORY
  // ==========================================================

  String _getInitialCategory() {
    if (widget.note != null) {
      _titleController.text =
          widget.note!.title;

      return widget.note!.category;
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
  // CREATE CONTROLLER
  // ==========================================================

  FleatherController
      _createController() {
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
              ParchmentDocument.fromJson(
            decoded,
          );

          return FleatherController(
            document:
                document,
          );
        }
      } catch (_) {}
    }

    return FleatherController();
  }

  // ==========================================================
  // EDITOR CHANGED
  // ==========================================================

  void _onEditorChanged() {
    _hasChanges = true;
    _scheduleAutoSave();
  }

  // ==========================================================
  // TITLE CHANGED
  // ==========================================================

  void _onTitleChanged() {
    _hasChanges = true;
    _scheduleAutoSave();
  }

  // ==========================================================
  // SCHEDULE AUTOSAVE
  // ==========================================================

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();

    _autoSaveTimer =
        Timer(
      const Duration(
        milliseconds: 700,
      ),
      () {
        _autoSave();
      },
    );
  }

  // ==========================================================
  // AUTOSAVE
  // ==========================================================

  Future<void> _autoSave() async {
    if (!_hasChanges ||
        _saving) {
      return;
    }

    _saving = true;

    try {
      final prefs =
          await SharedPreferences
              .getInstance();

      final title =
          _titleController.text
              .trim();

      final contentJson =
          jsonEncode(
        _controller
            .document
            .toDelta()
            .toJson(),
      );

      final note =
          Note(
        id: _noteId,

        title:
            title,

        contentJson:
            contentJson,

        category:
            _selectedCategory,
      );

      final notesString =
          prefs.getString(
        'local_notes_clean',
      );

      List<Note> notes =
          [];

      if (notesString != null &&
          notesString.isNotEmpty) {
        try {
          final decoded =
              jsonDecode(
            notesString,
          );

          if (decoded is List) {
            notes = decoded
                .map(
                  (item) =>
                      Note.fromMap(
                    Map<String,
                        dynamic>.from(
                      item,
                    ),
                  ),
                )
                .toList();
          }
        } catch (_) {}
      }

      final index =
          notes.indexWhere(
        (n) => n.id == _noteId,
      );

      final hasRealContent =
          title.isNotEmpty ||
              _controller
                  .document
                  .toPlainText()
                  .trim()
                  .isNotEmpty;

      if (index == -1) {
        if (hasRealContent) {
          notes.insert(
            0,
            note,
          );
        }
      } else {
        notes[index] =
            note;
      }

      await prefs.setString(
        'local_notes_clean',
        jsonEncode(
          notes
              .map(
                (n) => n.toMap(),
              )
              .toList(),
        ),
      );

      await prefs.setStringList(
        'local_categories',
        widget.categories,
      );

      _hasChanges = false;
    } catch (_) {
      // Автосохранение не должно
      // ломать работу редактора.
    } finally {
      _saving = false;
    }
  }

  // ==========================================================
  // SAVE NOTE
  // ==========================================================

  Future<void> _saveNote() async {
    await _autoSave();

    if (!mounted) {
      return;
    }

    final contentJson =
        jsonEncode(
      _controller
          .document
          .toDelta()
          .toJson(),
    );

    Navigator.pop(
      context,
      {
        'id':
            _noteId,

        'title':
            _titleController.text
                .trim(),

        'contentJson':
            contentJson,

        'category':
            _selectedCategory,
      },
    );
  }

  // ==========================================================
  // EXPORT TXT
  // ==========================================================

  Future<void>
      _saveToDevice() async {
    try {
      final title =
          _titleController.text
              .trim();

      final plainText =
          _controller
              .document
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

      final tempFile =
          File(
        '${tempDirectory.path}/'
        '${DateTime.now().microsecondsSinceEpoch}_'
        '$fileName',
      );

      await tempFile.writeAsString(
        plainText,
        encoding: utf8,
        flush: true,
      );

      if (!await tempFile
          .exists()) {
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
        if (await tempFile
            .exists()) {
          await tempFile
              .delete();
        }
      } catch (_) {}

      if (!mounted) {
        return;
      }

      if (savedPath != null &&
          savedPath.isNotEmpty) {
        _showMessage(
          'TXT сохранён на устройство',
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
  // CATEGORY
  // ==========================================================

  void _changeCategory(
    String? value,
  ) {
    if (value == null) {
      return;
    }

    setState(() {
      _selectedCategory =
          value;
    });

    _hasChanges = true;
    _scheduleAutoSave();
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

    ScaffoldMessenger.of(
      context,
    )
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
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
  // TOOLBAR
  // ==========================================================

  Widget _buildToolbar() {
    return FleatherToolbar.basic(
      controller:
          _controller,
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            TextField(
          controller:
              _titleController,

          style:
              const TextStyle(
            fontSize:
                20,
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
          // ==================================================
          // TXT
          // ==================================================

          IconButton(
            tooltip:
                'Сохранить как TXT',

            icon:
                const Icon(
              Icons
                  .file_download_outlined,
            ),

            onPressed:
                _saveToDevice,
          ),

          // ==================================================
          // SAVE
          // ==================================================

          IconButton(
            tooltip:
                'Сохранить',

            icon:
                const Icon(
              Icons.save,
            ),

            onPressed:
                _saveNote,
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
                    Icons
                        .folder_outlined,
                    size:
                        20,
                  ),

                  const SizedBox(
                    width:
                        8,
                  ),

                  const Text(
                    'Раздел:',
                  ),

                  const SizedBox(
                    width:
                        8,
                  ),

                  Expanded(
                    child:
                        DropdownButtonHideUnderline(
                      child:
                          DropdownButton<
                              String>(
                        value:
                            widget.categories
                                    .where(
                                      (c) =>
                                          c !=
                                          'Все',
                                    )
                                    .contains(
                          _selectedCategory,
                        )
                                ? _selectedCategory
                                : null,

                        isExpanded:
                            true,

                        items: widget
                            .categories
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
                            _changeCategory,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height:
                  1,
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
              height:
                  1,
            ),

            // =================================================
            // EDITOR
            // =================================================

            Expanded(
              child:
                  Padding(
                padding:
                    const EdgeInsets
                        .all(
                  8,
                ),

                child:
                    FleatherEditor(
                  controller:
                      _controller,

                  focusNode:
                      _focusNode,

                  padding:
                      const EdgeInsets
                          .all(
                    12,
                  ),

                  expands:
                      true,

                  autofocus:
                      false,

                  showCursor:
                      true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _autoSaveTimer
        ?.cancel();

    _controller
        .removeListener(
      _onEditorChanged,
    );

    _titleController
        .removeListener(
      _onTitleChanged,
    );

    _focusNode.dispose();

    _controller.dispose();

    _titleController
        .dispose();

    super.dispose();
  }
}
