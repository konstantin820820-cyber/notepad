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

// ============================================================
// APP
// ============================================================

class LocalNotesApp extends StatelessWidget {
  const LocalNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Локальный Блокнот',

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
    final prefs = await SharedPreferences.getInstance();

    final savedCategories =
        prefs.getStringList('local_categories');

    final notesString =
        prefs.getString('local_notes_v5');

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

    if (notesString != null &&
        notesString.isNotEmpty) {
      try {
        final decoded = jsonDecode(notesString);

        if (decoded is List) {
          notes = decoded
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

    final fallbackCategory =
        categories.length > 1
            ? categories[1]
            : 'Личное';

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

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = categories;
      _notes = notes;
      _loading = false;
    });
  }

  // ==========================================================
  // SAVE DATA
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
        _notes
            .map((note) => note.toMap())
            .toList(),
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
    final controller =
        TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Новый раздел',
          ),

          content: TextField(
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
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text(
                'Отмена',
              ),
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
              child: const Text(
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

    final newName = name.trim();

    if (_categories.contains(newName)) {
      _showMessage(
        'Такой раздел уже существует',
      );
      return;
    }

    setState(() {
      _categories.add(newName);
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
          title: const Text(
            'Переименовать раздел',
          ),

          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization:
                TextCapitalization.sentences,
          ),

          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text(
                'Отмена',
              ),
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
              child: const Text(
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
        newName.trim() == category) {
      return;
    }

    final trimmed = newName.trim();

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
          title: const Text(
            'Удалить раздел?',
          ),

          content: Text(
            notesCount == 0
                ? 'Раздел «$category» пуст.'
                : 'В разделе «$category» находится '
                    '$notesCount заметок.\n\n'
                    'Заметки будут перенесены '
                    'в первый доступный раздел.',
          ),

          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child: const Text(
                'Отмена',
              ),
            ),

            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child: const Text(
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

    final targetCategory =
        _categories.firstWhere(
      (c) =>
          c != 'Все' &&
          c != category,
      orElse: () => 'Личное',
    );

    setState(() {
      _categories.remove(category);

      for (final note in _notes) {
        if (note.category == category) {
          note.category =
              targetCategory;
        }
      }
    });

    final selectedIndex =
        (_tabController?.index ?? 0)
            .clamp(
      0,
      _categories.length - 1,
    );

    _recreateTabController(
      selectedIndex: selectedIndex,
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
              child: SizedBox(
                height:
                    MediaQuery.of(context)
                            .size
                            .height *
                        0.75,
                child: Column(
                  children: [
                    const Padding(
                      padding:
                          EdgeInsets.all(16),
                      child: Text(
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
                          ReorderableListView
                              .builder(
                        padding:
                            const EdgeInsets
                                .all(12),

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

                          String selectedCategory =
                              _categories[
                                  (_tabController
                                              ?.index ??
                                          0)
                                      .clamp(
                                0,
                                _categories
                                        .length -
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
                            key: ValueKey(
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
                                    MainAxisSize
                                        .min,
                                children: [
                                  IconButton(
                                    tooltip:
                                        'Переименовать',
                                    icon:
                                        const Icon(
                                      Icons
                                          .edit,
                                    ),
                                    onPressed:
                                        () async {
                                      Navigator
                                          .pop(
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
                                      Icons
                                          .delete_outline,
                                      color:
                                          Colors
                                              .redAccent,
                                    ),
                                    onPressed:
                                        () async {
                                      Navigator
                                          .pop(
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
                          const EdgeInsets
                              .all(16),
                      child: SizedBox(
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

  void _reorderNotes(
    String category,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex) {
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

    _saveData();
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
          title: const Text(
            'Удалить заметку?',
          ),

          content: Text(
            note.title.isEmpty
                ? 'Без названия'
                : note.title,
          ),

          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child: const Text(
                'Отмена',
              ),
            ),

            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child: const Text(
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
        _notes[index] = Note(
          id: note.id,
          title:
              result['title'] ??
                  '',
          contentJson:
              result['contentJson'] ??
                  '[{"insert":"\\n"}]',
          category:
              result['category'] ??
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
        _tabController?.index ?? 0;

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
          id: DateTime.now()
              .microsecondsSinceEpoch
              .toString(),

          title:
              result['title'] ??
                  '',

          contentJson:
              result['contentJson'] ??
                  '[{"insert":"\\n"}]',

          category:
              result['category'] ??
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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
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
        body: Center(
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
                'Управление разделами',
            icon:
                const Icon(
              Icons.folder_open,
            ),
            onPressed:
                _manageCategories,
          ),
        ],

        bottom: TabBar(
          controller:
              _tabController,
          isScrollable: true,
          tabs: _categories
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

      body: TabBarView(
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
                child: Text(
                  'Здесь пока пусто',
                  style:
                      TextStyle(
                    color: Colors
                        .white
                        .withOpacity(
                      0.54,
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding:
                  const EdgeInsets
                      .all(8),

              child:
                  ReorderableGridView
                      .builder(
                padding:
                    const EdgeInsets
                        .only(
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
                    filteredNotes
                        .length,

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
                    key: ValueKey(
                      note.id,
                    ),

                    child: InkWell(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),

                      onTap: () =>
                          _editNote(
                        note,
                      ),

                      child: Padding(
                        padding:
                            const EdgeInsets
                                .all(
                          12,
                        ),

                        child: Column(
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
                                      EdgeInsets
                                          .zero,

                                  icon:
                                      const Icon(
                                    Icons
                                        .more_vert,
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
                                            'Удалить',
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

class EditorScreen
    extends StatefulWidget {
  final Note? note;

  final List<String>
      categories;

  final String?
      initialCategory;

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
  final TextEditingController
      _titleController =
      TextEditingController();

  final FocusNode _focusNode =
      FocusNode();

  FleatherController?
      _controller;

  late String
      _selectedCategory;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    if (widget.note != null) {
      _titleController.text =
          widget.note!.title;

      _selectedCategory =
          widget.note!.category;

      try {
        final decoded =
            jsonDecode(
          widget.note!
              .contentJson,
        );

        _controller =
            FleatherController(
          document:
              ParchmentDocument
                  .fromJson(
            decoded,
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
              .where(
                (cat) =>
                    cat != 'Все',
              )
              .toList();

      if (widget.initialCategory !=
              null &&
          availableCategories
              .contains(
            widget.initialCategory,
          )) {
        _selectedCategory =
            widget.initialCategory!;
      } else if (availableCategories
          .contains('Личное')) {
        _selectedCategory =
            'Личное';
      } else if (availableCategories
          .isNotEmpty) {
        _selectedCategory =
            availableCategories
                .first;
      } else {
        _selectedCategory =
            'Личное';
      }
    }
  }

  // ==========================================================
  // SAVE NOTE
  // ==========================================================

  void _saveNote() {
    if (_controller == null) {
      return;
    }

    final contentJson =
        jsonEncode(
      _controller!
          .document
          .toJson(),
    );

    Navigator.pop(
      context,
      {
        'title':
            _titleController
                .text
                .trim(),

        'contentJson':
            contentJson,

        'category':
            _selectedCategory,
      },
    );
  }

  // ==========================================================
  // MARKDOWN ESCAPE
  // ==========================================================

  String _escapeMarkdownText(
    String text,
  ) {
    return text
        .replaceAll(
          r'\',
          r'\\',
        )
        .replaceAll(
          '*',
          r'\*',
        )
        .replaceAll(
          '_',
          r'\_',
        )
        .replaceAll(
          '`',
          r'\`',
        )
        .replaceAll(
          '[',
          r'\[',
        )
        .replaceAll(
          ']',
          r'\]',
        );
  }

  // ==========================================================
  // MARKDOWN INLINE
  // ==========================================================

  String _formatInlineMarkdown(
    String text,
    Map<String, dynamic>
        attributes,
  ) {
    if (text.isEmpty) {
      return '';
    }

    String result =
        _escapeMarkdownText(
      text,
    );

    final link =
        attributes['link'];

    if (link != null) {
      result =
          '[$result](${link.toString()})';
    }

    if (attributes['code'] ==
        true) {
      result =
          '`$result`';
    }

    if (attributes['bold'] ==
        true) {
      result =
          '**$result**';
    }

    if (attributes['italic'] ==
        true) {
      result =
          '*$result*';
    }

    if (attributes['strike'] ==
        true) {
      result =
          '~~$result~~';
    }

    return result;
  }

  // ==========================================================
  // BLOCK MARKDOWN
  // ==========================================================

  String _makeMarkdownBlock(
    String text,
    Map<String, dynamic>
        attributes,
  ) {
    final trimmed =
        text.trim();

    if (attributes['header'] ==
        1) {
      return '# $trimmed';
    }

    if (attributes['header'] ==
        2) {
      return '## $trimmed';
    }

    if (attributes['header'] ==
        3) {
      return '### $trimmed';
    }

    if (attributes['blockquote'] ==
        true) {
      if (trimmed.isEmpty) {
        return '>';
      }

      return '> $trimmed';
    }

    if (attributes['list'] ==
        'bullet') {
      return '- $trimmed';
    }

    if (attributes['list'] ==
        'ordered') {
      return '1. $trimmed';
    }

    return text;
  }

  // ==========================================================
  // DELTA -> MARKDOWN
  //
  // Здесь специально не используется split('\n')
  // для всей операции целиком.
  //
  // Мы последовательно собираем строки Delta.
  // Атрибуты самого символа перевода строки
  // используются как атрибуты блока.
  // ==========================================================

  String _deltaToMarkdown() {
    if (_controller == null) {
      return '';
    }

    final delta =
        _controller!
            .document
            .toDelta()
            .toJson();

    final output =
        StringBuffer();

    final currentLine =
        StringBuffer();

    Map<String, dynamic>
        currentBlockAttributes =
        <String, dynamic>{};

    bool wroteAnything = false;

    void writeLine(
      String text,
      Map<String, dynamic>
          blockAttributes,
    ) {
      final line =
          _makeMarkdownBlock(
        text,
        blockAttributes,
      );

      output.write(line);
      output.write('\n\n');

      wroteAnything = true;
    }

    for (final rawOperation in delta) {
      if (rawOperation is! Map) {
        continue;
      }

      if (!rawOperation.containsKey(
        'insert',
      )) {
        continue;
      }

      final insert =
          rawOperation['insert'];

      final attributes =
          rawOperation['attributes']
                  is Map
              ? Map<String, dynamic>.from(
                  rawOperation[
                      'attributes'],
                )
              : <String, dynamic>{};

      // --------------------------------------------------------
      // TEXT
      // --------------------------------------------------------

      if (insert is String) {
        String buffer =
            '';

        for (int i = 0;
            i < insert.length;
            i++) {
          final char =
              insert[i];

          if (char == '\n') {
            if (buffer.isNotEmpty) {
              currentLine.write(
                _formatInlineMarkdown(
                  buffer,
                  attributes,
                ),
              );

              buffer = '';
            }

            currentBlockAttributes =
                Map<String, dynamic>.from(
              attributes,
            );

            writeLine(
              currentLine.toString(),
              currentBlockAttributes,
            );

            currentLine.clear();

            currentBlockAttributes =
                <String, dynamic>{};
          } else {
            buffer += char;
          }
        }

        // Остаток текста после последнего \n.
        if (buffer.isNotEmpty) {
          currentLine.write(
            _formatInlineMarkdown(
              buffer,
              attributes,
            ),
          );
        }
      }

      // --------------------------------------------------------
      // EMBED / IMAGE
      // --------------------------------------------------------

      else if (insert is Map) {
        if (insert.containsKey(
          'image',
        )) {
          final image =
              insert['image']
                  .toString();

          currentLine.write(
            '![Изображение]($image)',
          );
        }
      }
    }

    // ----------------------------------------------------------
    // Последняя строка.
    // ----------------------------------------------------------

    if (currentLine.isNotEmpty) {
      writeLine(
        currentLine.toString(),
        currentBlockAttributes,
      );
    }

    // ----------------------------------------------------------
    // Если документ практически пустой.
    // ----------------------------------------------------------

    String result =
        output.toString().trimRight();

    // Заголовок добавляем отдельно.
    //
    // Он не берётся из Delta, потому что заголовок
    // заметки хранится отдельно.
    final title =
        _titleController.text.trim();

    if (title.isNotEmpty) {
      if (result.isEmpty) {
        result = '# $title';
      } else {
        result =
            '# $title\n\n$result';
      }
    }

    if (!wroteAnything &&
        title.isEmpty) {
      return '';
    }

    return '$result\n';
  }

  // ==========================================================
  // TEMP FILE NAME
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

    result = result.replaceAll(
      RegExp(
        r'[\\/:*?"<>|]',
      ),
      '_',
    );

    return result;
  }

  // ==========================================================
  // EXPORT MARKDOWN
  // ==========================================================

  Future<void>
      _saveToMarkdownFile() async {
    try {
      if (_controller == null) {
        throw Exception(
          'Редактор ещё не готов.',
        );
      }

      final markdown =
          _deltaToMarkdown();

      if (markdown.trim().isEmpty) {
        throw Exception(
          'Заметка пустая.',
        );
      }

      final fileName =
          '${_safeFileName(_titleController.text)}.md';

      // --------------------------------------------------------
      // Создаём временный файл в системной временной папке.
      //
      // Никакого getExternalStorageDirectory().
      // Поэтому дополнительный path_provider не нужен.
      // --------------------------------------------------------

      final tempDirectory =
          Directory.systemTemp;

      final tempFile =
          File(
        '${tempDirectory.path}/'
        '${DateTime.now().microsecondsSinceEpoch}_$fileName',
      );

      await tempFile.writeAsString(
        markdown,
        encoding: utf8,
        flush: true,
      );

      if (!await tempFile.exists()) {
        throw Exception(
          'Временный файл не создан.',
        );
      }

      final savedPath =
          await FlutterFileDialog.saveFile(
        params:
            SaveFileDialogParams(
          sourceFilePath:
              tempFile.path,
          fileName:
              fileName,
        ),
      );

      // Удаляем временный файл.
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
        ScaffoldMessenger.of(
          context,
        )
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Markdown успешно сохранён.',
              ),
              duration:
                  Duration(seconds: 3),
            ),
          );
      } else {
        ScaffoldMessenger.of(
          context,
        )
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Сохранение отменено.',
              ),
              duration:
                  Duration(seconds: 2),
            ),
          );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      )
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка сохранения Markdown:\n$e',
            ),
            duration:
                const Duration(seconds: 5),
          ),
        );
    }
  }

  // ==========================================================
  // FORMAT TOOLBAR
  // ==========================================================

  Widget _buildToolbar() {
    if (_controller == null) {
      return const SizedBox();
    }

    return FleatherToolbar.basic(
      controller:
          _controller!,
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_controller == null) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
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
          // ----------------------------------------------------
          // EXPORT MARKDOWN
          // ----------------------------------------------------

          IconButton(
            tooltip:
                'Экспорт в Markdown',

            icon:
                const Icon(
              Icons
                  .description_outlined,
            ),

            onPressed:
                _saveToMarkdownFile,
          ),

          // ----------------------------------------------------
          // SAVE NOTE
          // ----------------------------------------------------

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

      body: SafeArea(
        child: Column(
          children: [
            // --------------------------------------------------
            // CATEGORY
            // --------------------------------------------------

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
                          DropdownButton<String>(
                        value:
                            widget.categories.contains(
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

            // --------------------------------------------------
            // TOOLBAR
            // --------------------------------------------------

            SingleChildScrollView(
              scrollDirection:
                  Axis.horizontal,

              child:
                  _buildToolbar(),
            ),

            const Divider(
              height: 1,
            ),

            // --------------------------------------------------
            // EDITOR
            // --------------------------------------------------

            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets
                        .all(
                  8,
                ),

                child:
                    FleatherEditor(
                  controller:
                      _controller!,

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
    _focusNode.dispose();

    _controller?.dispose();

    _titleController.dispose();

    super.dispose();
  }
}
