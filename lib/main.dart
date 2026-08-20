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
  State<EditorScreen> createState() => _EditorScreenState();
}

// ============================================================
// EDITOR STATE
// ============================================================

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _titleController =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();

  FleatherController? _controller;

  late String _selectedCategory;

  bool _saving = false;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _selectedCategory = _getInitialCategory();

    _createController();
  }

  // ==========================================================
  // INITIAL CATEGORY
  // ==========================================================

  String _getInitialCategory() {
    final availableCategories = widget.categories
        .where((category) => category != 'Все')
        .toList();

    if (widget.note != null) {
      final noteCategory = widget.note!.category;

      if (availableCategories.contains(noteCategory)) {
        return noteCategory;
      }
    }

    if (widget.initialCategory != null &&
        availableCategories.contains(widget.initialCategory)) {
      return widget.initialCategory!;
    }

    if (availableCategories.contains('Личное')) {
      return 'Личное';
    }

    if (availableCategories.isNotEmpty) {
      return availableCategories.first;
    }

    return 'Личное';
  }

  // ==========================================================
  // CREATE FLEATHER CONTROLLER
  // ==========================================================

  void _createController() {
    // ----------------------------------------------------------
    // НОВАЯ ЗАМЕТКА
    // ----------------------------------------------------------

    if (widget.note == null) {
      _controller = FleatherController(
        document: ParchmentDocument(),
      );

      return;
    }

    // ----------------------------------------------------------
    // СУЩЕСТВУЮЩАЯ ЗАМЕТКА
    // ----------------------------------------------------------

    _titleController.text = widget.note!.title;

    try {
      final rawJson = widget.note!.contentJson;

      if (rawJson.trim().isEmpty) {
        _controller = FleatherController(
          document: ParchmentDocument(),
        );
        return;
      }

      final decoded = jsonDecode(rawJson);

      if (decoded is List) {
        _controller = FleatherController(
          document: ParchmentDocument.fromJson(
            decoded,
          ),
        );
      } else {
        _controller = FleatherController(
          document: ParchmentDocument(),
        );
      }
    } catch (e) {
      debugPrint(
        'Ошибка загрузки содержимого заметки: $e',
      );

      _controller = FleatherController(
        document: ParchmentDocument(),
      );
    }
  }

  // ==========================================================
  // SAVE NOTE TO APP
  // ==========================================================

  void _saveNote() {
    if (_controller == null) {
      return;
    }

    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final document = _controller!.document;

      final documentJson = document.toJson();

      final contentJson = jsonEncode(
        documentJson,
      );

      final title = _titleController.text.trim();

      Navigator.pop(
        context,
        <String, dynamic>{
          'title': title,
          'contentJson': contentJson,
          'category': _selectedCategory,
        },
      );
    } catch (e) {
      setState(() {
        _saving = false;
      });

      _showMessage(
        'Ошибка сохранения заметки:\n$e',
      );
    }
  }

  // ==========================================================
  // GET PLAIN TEXT
  //
  // Это принципиально важная часть.
  //
  // Мы НЕ пытаемся получать текст через наш старый
  // ручной разбор Delta.
  //
  // Parchment сам знает, где находится текст документа.
  // ==========================================================

  String _getPlainText() {
    if (_controller == null) {
      return '';
    }

    try {
      return _controller!.document.toPlainText();
    } catch (e) {
      debugPrint(
        'Ошибка получения plain text: $e',
      );

      return '';
    }
  }

  // ==========================================================
  // ESCAPE MARKDOWN
  // ==========================================================

  String _escapeMarkdownText(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll('*', r'\*')
        .replaceAll('_', r'\_')
        .replaceAll('`', r'\`')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]');
  }

  // ==========================================================
  // FORMAT INLINE
  // ==========================================================

  String _formatInlineMarkdown(
    String text,
    Map<String, dynamic> attributes,
  ) {
    if (text.isEmpty) {
      return '';
    }

    String result = _escapeMarkdownText(text);

    // --------------------------------------------------------
    // LINK
    // --------------------------------------------------------

    final link = attributes['link'];

    if (link != null) {
      result = '[$result](${link.toString()})';
    }

    // --------------------------------------------------------
    // CODE
    // --------------------------------------------------------

    if (attributes['code'] == true) {
      result = '`$result`';
    }

    // --------------------------------------------------------
    // BOLD
    // --------------------------------------------------------

    if (attributes['bold'] == true) {
      result = '**$result**';
    }

    // --------------------------------------------------------
    // ITALIC
    // --------------------------------------------------------

    if (attributes['italic'] == true) {
      result = '*$result*';
    }

    // --------------------------------------------------------
    // STRIKE
    // --------------------------------------------------------

    if (attributes['strike'] == true ||
        attributes['strikethrough'] == true) {
      result = '~~$result~~';
    }

    // --------------------------------------------------------
    // UNDERLINE
    //
    // В чистом Markdown стандартного underline нет.
    // Поэтому используем HTML.
    // --------------------------------------------------------

    if (attributes['underline'] == true) {
      result = '<u>$result</u>';
    }

    return result;
  }

  // ==========================================================
  // BLOCK FORMAT
  // ==========================================================

  String _formatMarkdownBlock(
    String text,
    Map<String, dynamic> attributes,
  ) {
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    // --------------------------------------------------------
    // HEADER
    // --------------------------------------------------------

    final header = attributes['header'];

    if (header == 1) {
      return '# $trimmed';
    }

    if (header == 2) {
      return '## $trimmed';
    }

    if (header == 3) {
      return '### $trimmed';
    }

    // --------------------------------------------------------
    // BLOCKQUOTE
    // --------------------------------------------------------

    if (attributes['blockquote'] == true) {
      return '> $trimmed';
    }

    // --------------------------------------------------------
    // BULLET LIST
    // --------------------------------------------------------

    if (attributes['list'] == 'bullet') {
      return '- $trimmed';
    }

    // --------------------------------------------------------
    // ORDERED LIST
    // --------------------------------------------------------

    if (attributes['list'] == 'ordered') {
      return '1. $trimmed';
    }

    return text;
  }

  // ==========================================================
  // DELTA -> MARKDOWN
  //
  // Здесь мы НЕ используем этот метод для извлечения текста.
  //
  // Текст сначала гарантированно берётся через:
  //
  // document.toPlainText()
  //
  // Delta используется только для попытки сохранить
  // форматирование.
  // ==========================================================

  String _deltaToMarkdown() {
    if (_controller == null) {
      return '';
    }

    final document = _controller!.document;

    // --------------------------------------------------------
    // САМОЕ ГЛАВНОЕ:
    //
    // Получаем настоящий текст документа напрямую.
    // --------------------------------------------------------

    final plainText = document.toPlainText();

    debugPrint(
      'Markdown export plain text length: ${plainText.length}',
    );

    debugPrint(
      'Markdown export plain text: $plainText',
    );

    // --------------------------------------------------------
    // Если текста нет, пробуем всё равно получить Delta.
    // --------------------------------------------------------

    if (plainText.trim().isEmpty) {
      return '';
    }

    final delta = document.toDelta().toJson();

    final output = StringBuffer();

    final currentLine = StringBuffer();

    Map<String, dynamic> currentAttributes =
        <String, dynamic>{};

    void writeCurrentLine() {
      final text = currentLine.toString();

      if (text.isEmpty) {
        output.write('\n');
      } else {
        output.write(
          _formatMarkdownBlock(
            text,
            currentAttributes,
          ),
        );

        output.write('\n');
      }

      currentLine.clear();

      currentAttributes = <String, dynamic>{};
    }

    // --------------------------------------------------------
    // Разбираем Delta.
    // --------------------------------------------------------

    for (final rawOperation in delta) {
      if (rawOperation is! Map) {
        continue;
      }

      if (!rawOperation.containsKey('insert')) {
        continue;
      }

      final insert = rawOperation['insert'];

      final attributes =
          rawOperation['attributes'] is Map
              ? Map<String, dynamic>.from(
                  rawOperation['attributes'] as Map,
                )
              : <String, dynamic>{};

      // ------------------------------------------------------
      // TEXT
      // ------------------------------------------------------

      if (insert is String) {
        final parts = insert.split('\n');

        for (int i = 0; i < parts.length; i++) {
          final part = parts[i];

          if (part.isNotEmpty) {
            currentLine.write(
              _formatInlineMarkdown(
                part,
                attributes,
              ),
            );
          }

          if (i < parts.length - 1) {
            currentAttributes =
                Map<String, dynamic>.from(
              attributes,
            );

            writeCurrentLine();
          }
        }

        continue;
      }

      // ------------------------------------------------------
      // EMBED / IMAGE
      // ------------------------------------------------------

      if (insert is Map) {
        final image = insert['image'];

        if (image != null) {
          currentLine.write(
            '![Изображение](${image.toString()})',
          );
        }
      }
    }

    // --------------------------------------------------------
    // Последняя строка.
    // --------------------------------------------------------

    if (currentLine.isNotEmpty) {
      writeCurrentLine();
    }

    var result = output.toString();

    // --------------------------------------------------------
    // НОРМАЛИЗУЕМ ПУСТЫЕ СТРОКИ.
    // --------------------------------------------------------

    result = result
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    // --------------------------------------------------------
    // КРИТИЧЕСКАЯ ЗАЩИТА.
    //
    // Если наш разбор Delta почему-то дал пустой результат,
    // НИКОГДА не сохраняем пустой Markdown.
    //
    // Берём plainText напрямую.
    // --------------------------------------------------------

    if (result.isEmpty &&
        plainText.trim().isNotEmpty) {
      result = plainText.trim();
    }

    // --------------------------------------------------------
    // Ещё одна проверка.
    //
    // Если в результате Delta потерялась существенная часть
    // текста, используем безопасный plain text.
    // --------------------------------------------------------

    final sourceTextLength =
        plainText.trim().length;

    final resultTextLength =
        result.replaceAll(
          RegExp(r'[*_`#>\-\[\]\(\)]'),
          '',
        ).trim().length;

    if (sourceTextLength > 20 &&
        resultTextLength <
            (sourceTextLength * 0.5)) {
      debugPrint(
        'Delta Markdown выглядит подозрительно. '
        'Используем plain text.',
      );

      result = plainText.trim();
    }

    // --------------------------------------------------------
    // ЗАГОЛОВОК ЗАМЕТКИ.
    // --------------------------------------------------------

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

    if (result.trim().isEmpty) {
      return '';
    }

    return '$result\n';
  }

  // ==========================================================
  // SAFE FILE NAME
  // ==========================================================

  String _safeFileName(String value) {
    var result = value.trim();

    if (result.isEmpty) {
      result = 'untitled_note';
    }

    result = result.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    return result;
  }

  // ==========================================================
  // EXPORT MARKDOWN
  // ==========================================================

  Future<void> _saveToMarkdownFile() async {
    try {
      if (_controller == null) {
        throw Exception(
          'Редактор ещё не готов.',
        );
      }

      // ------------------------------------------------------
      // Получаем Markdown.
      // ------------------------------------------------------

      final markdown = _deltaToMarkdown();

      // ------------------------------------------------------
      // НИКАКОГО СОХРАНЕНИЯ ПУСТОГО ФАЙЛА.
      // ------------------------------------------------------

      if (markdown.trim().isEmpty) {
        throw Exception(
          'Заметка действительно пустая.',
        );
      }

      // ------------------------------------------------------
      // DEBUG
      //
      // Это позволит нам увидеть в logcat/console,
      // что именно приложение пытается сохранить.
      // ------------------------------------------------------

      debugPrint(
        '========================================',
      );

      debugPrint(
        'MARKDOWN TO SAVE:',
      );

      debugPrint(markdown);

      debugPrint(
        'MARKDOWN LENGTH: ${markdown.length}',
      );

      debugPrint(
        '========================================',
      );

      // ------------------------------------------------------
      // ИМЯ ФАЙЛА
      // ------------------------------------------------------

      final fileName =
          '${_safeFileName(_titleController.text)}.md';

      // ------------------------------------------------------
      // TEMP FILE
      // ------------------------------------------------------

      final tempDirectory =
          Directory.systemTemp;

      final tempFile = File(
        '${tempDirectory.path}/'
        '${DateTime.now().microsecondsSinceEpoch}_'
        '$fileName',
      );

      // ------------------------------------------------------
      // Записываем UTF-8.
      // ------------------------------------------------------

      await tempFile.writeAsString(
        markdown,
        encoding: utf8,
        flush: true,
      );

      // ------------------------------------------------------
      // Проверяем, что файл реально существует.
      // ------------------------------------------------------

      if (!await tempFile.exists()) {
        throw Exception(
          'Временный файл не создан.',
        );
      }

      // ------------------------------------------------------
      // Проверяем размер.
      // ------------------------------------------------------

      final fileLength =
          await tempFile.length();

      debugPrint(
        'TEMP FILE: ${tempFile.path}',
      );

      debugPrint(
        'TEMP FILE SIZE: $fileLength bytes',
      );

      if (fileLength == 0) {
        throw Exception(
          'Создан пустой временный файл.',
        );
      }

      // ------------------------------------------------------
      // ANDROID FILE PICKER
      // ------------------------------------------------------

      final savedPath =
          await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath:
              tempFile.path,
          fileName: fileName,
        ),
      );

      // ------------------------------------------------------
      // Удаляем временный файл.
      // ------------------------------------------------------

      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      // ------------------------------------------------------
      // RESULT
      // ------------------------------------------------------

      if (!mounted) {
        return;
      }

      if (savedPath != null &&
          savedPath.isNotEmpty) {
        ScaffoldMessenger.of(context)
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
        ScaffoldMessenger.of(context)
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
    } catch (e, stackTrace) {
      debugPrint(
        'Ошибка Markdown export: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка сохранения Markdown:\n$e',
            ),
            duration:
                const Duration(seconds: 6),
          ),
        );
    }
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
          duration:
              const Duration(seconds: 3),
        ),
      );
  }

  // ==========================================================
  // TOOLBAR
  // ==========================================================

  Widget _buildToolbar() {
    if (_controller == null) {
      return const SizedBox();
    }

    return FleatherToolbar.basic(
      controller: _controller!,
    );
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

    final availableCategories =
        widget.categories
            .where(
              (category) =>
                  category != 'Все',
            )
            .toList();

    final validCategory =
        availableCategories.contains(
      _selectedCategory,
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller:
              _titleController,

          style: const TextStyle(
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
          // MARKDOWN
          // ----------------------------------------------------

          IconButton(
            tooltip:
                'Экспорт в Markdown',

            icon:
                const Icon(
              Icons.description_outlined,
            ),

            onPressed:
                _saveToMarkdownFile,
          ),

          // ----------------------------------------------------
          // SAVE
          // ----------------------------------------------------

          IconButton(
            tooltip:
                'Сохранить',

            icon:
                const Icon(
              Icons.save,
            ),

            onPressed:
                _saving
                    ? null
                    : _saveNote,
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // CATEGORY
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                4,
              ),

              child: Row(
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
                            validCategory
                                ? _selectedCategory
                                : null,

                        isExpanded:
                            true,

                        items:
                            availableCategories
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
                        ).toList(),

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

            // ==================================================
            // TOOLBAR
            // ==================================================

            SingleChildScrollView(
              scrollDirection:
                  Axis.horizontal,

              child:
                  _buildToolbar(),
            ),

            const Divider(
              height: 1,
            ),

            // ==================================================
            // EDITOR
            // ==================================================

            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  8,
                ),

                child:
                    FleatherEditor(
                  controller:
                      _controller!,

                  focusNode:
                      _focusNode,

                  padding:
                      const EdgeInsets.all(
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
