import 'dart:convert';
import 'dart:typed_data';

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
        final decoded = jsonDecode(
          notesString,
        );

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

    final fallbackCategory =
        categories.length > 1
            ? categories[1]
            : 'Личное';

    for (final note in notes) {
      if (!categories.contains(note.category)) {
        note.category = fallbackCategory;
      }
    }

    _notes = notes;
    _categories = categories;

    _createTabController(
      selectedIndex: 0,
      updateState: false,
    );

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
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
      'local_notes_v5',
      jsonEncode(
        _notes
            .map(
              (note) => note.toMap(),
            )
            .toList(),
      ),
    );
  }

  // ==========================================================
  // TAB CONTROLLER
  // ==========================================================

  void _createTabController({
    int selectedIndex = 0,
    bool updateState = true,
  }) {
    _tabController?.dispose();

    _tabController = TabController(
      length: _categories.length,
      vsync: this,
    );

    final int safeIndex =
        selectedIndex
            .clamp(
              0,
              _categories.length - 1,
            );

    _tabController!.index = safeIndex;

    _tabController!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    if (updateState && mounted) {
      setState(() {});
    }
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
              hintText:
                  'Например: Статьи',
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

    final newName =
        name.trim();

    if (_categories.contains(newName)) {
      _showMessage(
        'Такой раздел уже существует',
      );
      return;
    }

    setState(() {
      _categories.add(newName);
    });

    _createTabController(
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

    final trimmed =
        newName.trim();

    if (_categories.contains(trimmed)) {
      _showMessage(
        'Такой раздел уже существует',
      );
      return;
    }

    final oldIndex =
        _categories.indexOf(category);

    setState(() {
      if (oldIndex != -1) {
        _categories[oldIndex] =
            trimmed;
      }

      for (final note in _notes) {
        if (note.category ==
            category) {
          note.category =
              trimmed;
        }
      }
    });

    _createTabController(
      selectedIndex: oldIndex,
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
          title: const Text(
            'Удалить раздел?',
          ),

          content: Text(
            notesCount == 0
                ? 'Раздел «$category» пуст.'
                : 'В разделе «$category» находится '
                    '$notesCount заметок.\n\n'
                    'Заметки будут перенесены '
                    'в другой раздел.',
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

    final targetCategory =
        _categories.firstWhere(
      (c) =>
          c != 'Все' &&
          c != category,
      orElse: () => 'Личное',
    );

    final oldIndex =
        _categories.indexOf(
      category,
    );

    setState(() {
      _categories.remove(
        category,
      );

      for (final note in _notes) {
        if (note.category ==
            category) {
          note.category =
              targetCategory;
        }
      }
    });

    final safeIndex =
        (oldIndex - 1).clamp(
      0,
      _categories.length - 1,
    );

    _createTabController(
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
              child: SizedBox(
                height:
                    MediaQuery.of(
                          context,
                        ).size.height *
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
                      style: TextStyle(
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

                          final selectedCategory =
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

                          _createTabController(
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
                                      Icons
                                          .delete_outline,
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
        ),
      ),
    );

    if (result == null ||
        result is! Map) {
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
    final int currentIndex =
        _tabController?.index ?? 0;

    String defaultCategory =
        'Личное';

    if (currentIndex > 0 &&
        currentIndex <
            _categories.length) {
      defaultCategory =
          _categories[currentIndex];
    } else if (_categories.length >
        1) {
      defaultCategory =
          _categories[1];
    }

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

    if (result == null ||
        result is! Map) {
      return;
    }

    setState(() {
      _notes.add(
        Note(
          id: DateTime.now()
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
  // BUILD HOME
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

          isScrollable:
              true,

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
                child: Text(
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
                  ReorderableGridView
                      .builder(
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
                  milliseconds: 450,
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
                                    note.title.isEmpty
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
  // DISPOSE HOME
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

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _titleController =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();

  late FleatherController _controller;

  late String _selectedCategory;

  bool _savingMarkdown = false;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _selectedCategory = _getInitialCategory();

    if (widget.note != null) {
      _titleController.text = widget.note!.title;

      try {
        final decoded = jsonDecode(
          widget.note!.contentJson,
        );

        _controller = FleatherController(
          document: ParchmentDocument.fromJson(decoded),
        );
      } catch (_) {
        _controller = FleatherController();
      }
    } else {
      _controller = FleatherController();
    }
  }

  // ==========================================================
  // INITIAL CATEGORY
  // ==========================================================

  String _getInitialCategory() {
    final available = widget.categories
        .where((category) => category != 'Все')
        .toList();

    if (widget.initialCategory != null &&
        available.contains(widget.initialCategory)) {
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
  // NORMALIZE FILE NAME
  // ==========================================================

  String _safeFileName(String value) {
    var result = value.trim();

    if (result.isEmpty) {
      result = 'Заметка';
    }

    result = result.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    result = result.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return result;
  }

  // ==========================================================
  // MARKDOWN ESCAPE
  // ==========================================================

  String _escapeMarkdownText(String text) {
    if (text.isEmpty) {
      return '';
    }

    return text
        .replaceAll(r'\', r'\\')
        .replaceAll('*', r'\*')
        .replaceAll('_', r'\_')
        .replaceAll('`', r'\`')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]');
  }

  // ==========================================================
  // APPLY INLINE MARKDOWN
  // ==========================================================

  String _formatInlineMarkdown(
    String text,
    Map<String, dynamic> attributes,
  ) {
    if (text.isEmpty) {
      return '';
    }

    var result = _escapeMarkdownText(text);

    // Ссылка должна быть обработана
    // после экранирования текста.
    final link = attributes['link'];

    if (attributes['code'] == true) {
      result = '`$result`';
    }

    if (attributes['bold'] == true) {
      result = '**$result**';
    }

    if (attributes['italic'] == true) {
      result = '*$result*';
    }

    if (attributes['strike'] == true) {
      result = '~~$result~~';
    }

    if (link != null) {
      final url = link.toString();

      result = '[$result]($url)';
    }

    return result;
  }

  // ==========================================================
  // DELTA -> MARKDOWN
  //
  // ВАЖНО:
  // Delta Fleather хранит формат абзаца обычно
  // на операции с символом "\n".
  //
  // Поэтому мы сначала собираем строку,
  // а формат строки берём из атрибутов "\n".
  // ==========================================================

  String _deltaToMarkdown() {
    final delta = _controller.document.toDelta().toJson();

    final StringBuffer output = StringBuffer();

    final String title = _titleController.text.trim();

    if (title.isNotEmpty) {
      output.writeln('# ${_escapeMarkdownText(title)}');
      output.writeln();
    }

    String currentLine = '';

    Map<String, dynamic> currentInlineAttributes = {};

    void writeLine(
      String text,
      Map<String, dynamic> blockAttributes,
    ) {
      var result = text;

      // Если в строке нет текста —
      // сохраняем пустую строку.
      if (result.isEmpty) {
        output.writeln();
        return;
      }

      // ------------------------------------------------------
      // INLINE
      // ------------------------------------------------------

      result = _formatInlineMarkdown(
        result,
        currentInlineAttributes,
      );

      // ------------------------------------------------------
      // BLOCK
      // ------------------------------------------------------

      final header = blockAttributes['header'];

      if (header == 1) {
        result = '# $result';
      } else if (header == 2) {
        result = '## $result';
      } else if (header == 3) {
        result = '### $result';
      } else if (blockAttributes['blockquote'] == true) {
        result = '> $result';
      } else if (blockAttributes['list'] == 'bullet') {
        result = '- $result';
      } else if (blockAttributes['list'] == 'ordered') {
        result = '1. $result';
      }

      output.writeln(result);
    }

    for (final rawOperation in delta) {
      if (rawOperation is! Map) {
        continue;
      }

      if (!rawOperation.containsKey('insert')) {
        continue;
      }

      final insert = rawOperation['insert'];

      final operationAttributes =
          rawOperation['attributes'] is Map
              ? Map<String, dynamic>.from(
                  rawOperation['attributes'],
                )
              : <String, dynamic>{};

      // ======================================================
      // TEXT
      // ======================================================

      if (insert is String) {
        final parts = insert.split('\n');

        for (int i = 0; i < parts.length; i++) {
          final part = parts[i];

          if (part.isNotEmpty) {
            currentLine += _formatInlineMarkdown(
              part,
              operationAttributes,
            );
          }

          // Есть перенос строки.
          if (i < parts.length - 1) {
            final blockAttributes =
                Map<String, dynamic>.from(
              operationAttributes,
            );

            // Если текущая операция содержит только
            // "\n" с форматированием абзаца,
            // используем именно эти атрибуты.
            writeLine(
              currentLine,
              blockAttributes,
            );

            currentLine = '';
            currentInlineAttributes = {};
          } else {
            if (part.isNotEmpty) {
              currentInlineAttributes =
                  Map<String, dynamic>.from(
                operationAttributes,
              );
            }
          }
        }

        continue;
      }

      // ======================================================
      // EMBED / IMAGE
      // ======================================================

      if (insert is Map) {
        if (insert.containsKey('image')) {
          final imageSource =
              insert['image']?.toString() ?? '';

          if (currentLine.isNotEmpty) {
            output.writeln(currentLine);
            currentLine = '';
          }

          if (imageSource.isNotEmpty) {
            output.writeln(
              '![Изображение]($imageSource)',
            );
            output.writeln();
          }
        }
      }
    }

    // ========================================================
    // ОСТАТОК ТЕКСТА
    // ========================================================

    if (currentLine.isNotEmpty) {
      output.writeln(currentLine);
    }

    var result = output.toString();

    // Убираем слишком много пустых строк в конце.
    result = result.trimRight();

    if (result.isEmpty) {
      result = '# ${title.isEmpty ? 'Заметка' : _escapeMarkdownText(title)}';
    }

    result += '\n';

    return result;
  }

  // ==========================================================
  // SAVE MARKDOWN
  // ==========================================================

  Future<void> _saveToMarkdownFile() async {
    if (_savingMarkdown) {
      return;
    }

    setState(() {
      _savingMarkdown = true;
    });

    try {
      final markdown = _deltaToMarkdown();

      final bytes = Uint8List.fromList(
        utf8.encode(markdown),
      );

      final fileName =
          '${_safeFileName(_titleController.text)}.md';

      final params = SaveFileDialogParams(
        data: bytes,
        fileName: fileName,
        mimeTypesFilter: const [
          'text/markdown',
          'text/plain',
        ],
        localOnly: true,
      );

      final savedPath =
          await FlutterFileDialog.saveFile(
        params: params,
      );

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
          SnackBar(
            content: Text(
              'Markdown сохранён:\n$savedPath',
            ),
            duration: const Duration(seconds: 4),
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
              'Ошибка сохранения Markdown:\n$e',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _savingMarkdown = false;
        });
      }
    }
  }

  // ==========================================================
  // SAVE NOTE
  // ==========================================================

  void _saveNote() {
    final contentJson = jsonEncode(
      _controller.document.toDelta().toJson(),
    );

    Navigator.pop(
      context,
      {
        'title': _titleController.text.trim(),
        'contentJson': contentJson,
        'category': _selectedCategory,
      },
    );
  }

  // ==========================================================
  // CONFIRM CLOSE
  // ==========================================================

  Future<bool> _confirmClose() async {
    return true;
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories
        .where((category) => category != 'Все')
        .toList();

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Редактор'),

          actions: [
            // --------------------------------------------------
            // EXPORT MARKDOWN
            // --------------------------------------------------

            IconButton(
              tooltip: 'Экспорт в Markdown',
              onPressed:
                  _savingMarkdown
                      ? null
                      : _saveToMarkdownFile,
              icon: _savingMarkdown
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.description_outlined,
                    ),
            ),

            // --------------------------------------------------
            // SAVE NOTE
            // --------------------------------------------------

            IconButton(
              tooltip: 'Сохранить заметку',
              onPressed: _saveNote,
              icon: const Icon(
                Icons.save,
              ),
            ),
          ],
        ),

        body: Column(
          children: [
            // ==================================================
            // TITLE
            // ==================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                4,
              ),

              child: TextField(
                controller: _titleController,
                textInputAction:
                    TextInputAction.next,

                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),

                decoration:
                    const InputDecoration(
                  hintText: 'Название заметки',
                  border: InputBorder.none,
                ),
              ),
            ),

            // ==================================================
            // CATEGORY
            // ==================================================

            if (categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),

                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 18,
                    ),

                    const SizedBox(width: 8),

                    const Text(
                      'Раздел:',
                    ),

                    const SizedBox(width: 8),

                    DropdownButton<String>(
                      value: categories.contains(
                        _selectedCategory,
                      )
                          ? _selectedCategory
                          : categories.first,

                      items: categories
                          .map(
                            (category) =>
                                DropdownMenuItem<String>(
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
                          _selectedCategory = value;
                        });
                      },
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

            Material(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,

              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,

                child: FleatherToolbar.basic(
                  controller: _controller,
                ),
              ),
            ),

            // ==================================================
            // EDITOR
            // ==================================================

            Expanded(
              child: FleatherEditor(
                controller: _controller,
                focusNode: _focusNode,

                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  120,
                ),

                expands: true,
                scrollable: true,
                autofocus: false,
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
    _controller.dispose();
    _titleController.dispose();

    super.dispose();
  }
}
