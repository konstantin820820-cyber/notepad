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
          DateTime.now().millisecondsSinceEpoch.toString(),

      title: map['title']?.toString() ?? '',

      contentJson:
          map['contentJson']?.toString() ??
              '[{"insert":"\\n"}]',

      category:
          map['category']?.toString() ?? 'Личное',
    );
  }
}

// ============================================================
// HOME SCREEN
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
      categories =
          List<String>.from(savedCategories);

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

    _createTabController(
      selectedIndex: 0,
      callSetState: false,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = categories;
      _notes = notes;
      _loading = false;
    });

    _createTabController(
      selectedIndex: 0,
      callSetState: false,
    );
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
            .map((note) => note.toMap())
            .toList(),
      ),
    );
  }

  // ==========================================================
  // TAB CONTROLLER
  // ==========================================================

  void _createTabController({
    int selectedIndex = 0,
    bool callSetState = true,
  }) {
    _tabController?.dispose();

    if (_categories.isEmpty) {
      return;
    }

    _tabController = TabController(
      length: _categories.length,
      vsync: this,
    );

    final safeIndex =
        selectedIndex.clamp(
      0,
      _categories.length - 1,
    );

    _tabController!.index = safeIndex;

    _tabController!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    if (callSetState && mounted) {
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
      builder: (dialogContext) {
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
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
                    dialogContext,
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
      builder: (dialogContext) {
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
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
                    dialogContext,
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

    if (newName == null) {
      return;
    }

    final trimmed =
        newName.trim();

    if (trimmed.isEmpty ||
        trimmed == category) {
      return;
    }

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
        if (note.category ==
            category) {
          note.category = trimmed;
        }
      }
    });

    final selectedIndex =
        _categories.indexOf(trimmed);

    _createTabController(
      selectedIndex:
          selectedIndex >= 0
              ? selectedIndex
              : 0,
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
      builder: (dialogContext) {
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
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
                  dialogContext,
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

    final otherCategories =
        _categories
            .where(
              (c) =>
                  c != 'Все' &&
                  c != category,
            )
            .toList();

    final targetCategory =
        otherCategories.isNotEmpty
            ? otherCategories.first
            : 'Личное';

    setState(() {
      _categories.remove(category);

      for (final note in _notes) {
        if (note.category ==
            category) {
          note.category =
              targetCategory;
        }
      }
    });

    if (_categories.length ==
        1) {
      // Если удалили последний пользовательский
      // раздел — создаём «Личное».
      _categories.add(
        'Личное',
      );

      for (final note in _notes) {
        if (note.category ==
            category) {
          note.category =
              'Личное';
        }
      }
    }

    _createTabController(
      selectedIndex: 0,
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
      builder: (sheetContext) {
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
                      'Удерживайте раздел и '
                      'перетащите его',
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

                          if (fromIndex <
                                  1 ||
                              fromIndex >=
                                  _categories
                                      .length) {
                            return;
                          }

                          if (toIndex <
                                  1 ||
                              toIndex >=
                                  _categories
                                      .length) {
                            return;
                          }

                          final selectedCategory =
                              _tabController
                                  ?.index !=
                                  null
                                  ? _categories[
                                      _tabController!
                                          .index]
                                  : 'Все';

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

                          modalSetState(
                            () {},
                          );

                          final selectedNewIndex =
                              _categories
                                  .indexOf(
                            selectedCategory,
                          );

                          _createTabController(
                            selectedIndex:
                                selectedNewIndex >=
                                        0
                                    ? selectedNewIndex
                                    : 0,
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
                                          Colors
                                              .redAccent,
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
                          const EdgeInsets
                              .all(16),

                      child:
                          SizedBox(
                        width:
                            double.infinity,

                        child:
                            FilledButton
                                .icon(
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

    if (newIndex < 0) {
      newIndex = 0;
    }

    if (newIndex >=
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
      builder: (dialogContext) {
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
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
                  dialogContext,
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
    final currentIndex =
        _tabController?.index ?? 0;

    String defaultCategory;

    if (currentIndex > 0 &&
        currentIndex <
            _categories.length) {
      defaultCategory =
          _categories[
              currentIndex];
    } else if (_categories
        .length >
        1) {
      defaultCategory =
          _categories[1];
    } else {
      defaultCategory =
          'Личное';
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
          id: DateTime
              .now()
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
  // BUILD HOME
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading ||
        _tabController ==
            null) {
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
            _categories
                .map(
                  (category) {
                    final filteredNotes =
                        category ==
                                'Все'
                            ? List<
                                Note>.from(
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

                              onTap:
                                  () =>
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
                )
                .toList(),
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
// EDITOR SCREEN
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
  State<EditorScreen>
      createState() =>
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

  final FocusNode
      _focusNode =
      FocusNode();

  FleatherController?
      _controller;

  late String
      _selectedCategory;

  bool _saving = false;

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
  // ESCAPE MARKDOWN
  // ==========================================================

  String _escapeMarkdown(
    String text,
  ) {
    return text
        .replaceAll(
          '\\',
          '\\\\',
        )
        .replaceAll(
          '`',
          '\\`',
        )
        .replaceAll(
          '*',
          '\\*',
        )
        .replaceAll(
          '_',
          '\\_',
        )
        .replaceAll(
          '[',
          '\\[',
        )
        .replaceAll(
          ']',
          '\\]',
        );
  }

  // ==========================================================
  // INLINE MARKDOWN
  // ==========================================================

  String _formatMarkdownText(
    String text,
    Map<String, dynamic>
        attributes,
  ) {
    if (text.isEmpty) {
      return '';
    }

    var result =
        _escapeMarkdown(
      text,
    );

    if (attributes['link'] !=
        null) {
      final url =
          attributes['link']
              .toString();

      result =
          '[$result]($url)';
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
  // DELTA -> MARKDOWN
  // ==========================================================

  String _deltaToMarkdown() {
    if (_controller ==
        null) {
      return '';
    }

    final delta =
        _controller!
            .document
            .toDelta()
            .toJson();

    final StringBuffer
        markdown =
        StringBuffer();

    final title =
        _titleController
            .text
            .trim();

    if (title.isNotEmpty) {
      markdown.writeln(
        '# $title',
      );

      markdown.writeln();
    }

    for (final operation
        in delta) {
      if (operation is! Map) {
        continue;
      }

      if (!operation
          .containsKey(
        'insert',
      )) {
        continue;
      }

      final insert =
          operation['insert'];

      final attributes =
          operation['attributes']
                  is Map
              ? Map<String, dynamic>
                  .from(
                  operation[
                      'attributes'] as Map,
                )
              : <String, dynamic>{};

      // --------------------------------------------------------
      // TEXT
      // --------------------------------------------------------

      if (insert is String) {
        final lines =
            insert.split('\n');

        for (
          int i = 0;
          i < lines.length;
          i++
        ) {
          var text =
              _formatMarkdownText(
            lines[i],
            attributes,
          );

          if (attributes[
                  'header'] ==
              1) {
            text =
                '# $text';
          } else if (attributes[
                  'header'] ==
              2) {
            text =
                '## $text';
          } else if (attributes[
                  'header'] ==
              3) {
            text =
                '### $text';
          }

          if (attributes[
                  'blockquote'] ==
              true) {
            text =
                '> $text';
          }

          if (attributes[
                  'list'] ==
              'bullet') {
            text =
                '- $text';
          } else if (attributes[
                  'list'] ==
              'ordered') {
            text =
                '1. $text';
          }

          markdown.write(
            text,
          );

          if (i <
              lines.length - 1) {
            markdown.write(
              '\n',
            );
          }
        }

        continue;
      }

      // --------------------------------------------------------
      // IMAGE
      // --------------------------------------------------------

      if (insert is Map) {
        if (insert.containsKey(
          'image',
        )) {
          final image =
              insert['image']
                  .toString();

          markdown.writeln(
            '![Изображение]($image)',
          );
        }
      }
    }

    return markdown.toString();
  }

  // ==========================================================
  // SAVE MARKDOWN
  // ==========================================================

  Future<void>
      _saveToMarkdownFile() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final markdown =
          _deltaToMarkdown();

      if (markdown.trim().isEmpty) {
        throw Exception(
          'Заметка пустая.',
        );
      }

      var fileName =
          _titleController
              .text
              .trim();

      if (fileName.isEmpty) {
        fileName =
            'Заметка';
      }

      fileName =
          fileName.replaceAll(
        RegExp(
          r'[\\/:*?"<>|]',
        ),
        '_',
      );

      if (!fileName
          .toLowerCase()
          .endsWith('.md')) {
        fileName =
            '$fileName.md';
      }

      // ========================================================
      // TEMP FILE
      // ========================================================

      final tempDirectory =
          Directory.systemTemp;

      final tempFile =
          File(
        '${tempDirectory.path}/$fileName',
      );

      await tempFile
          .writeAsString(
        markdown,
        encoding: utf8,
        flush: true,
      );

      if (!await tempFile
          .exists()) {
        throw Exception(
          'Не удалось создать временный файл.',
        );
      }

      final fileSize =
          await tempFile
              .length();

      if (fileSize <= 0) {
        throw Exception(
          'Markdown-файл получился пустым.',
        );
      }

      // ========================================================
      // ANDROID SAVE DIALOG
      // ========================================================

      final params =
          SaveFileDialogParams(
        sourceFilePath:
            tempFile.path,
        fileName:
            fileName,
      );

      final savedPath =
          await FlutterFileDialog
              .saveFile(
        params: params,
      );

      // ========================================================
      // CLEAN TEMP
      // ========================================================

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

      if (savedPath ==
          null) {
        _showMessage(
          'Сохранение отменено.',
        );

        return;
      }

      _showMessage(
        'Markdown сохранён.\n'
        'Размер: $fileSize байт',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Ошибка сохранения:\n$e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================================
  // SAVE NOTE
  // ==========================================================

  void _saveNote() {
    if (_controller ==
        null) {
      return;
    }

    final title =
        _titleController
            .text
            .trim();

    final content =
        jsonEncode(
      _controller!
          .document
          .toJson(),
    );

    Navigator.pop(
      context,
      {
        'title': title,
        'contentJson':
            content,
        'category':
            _selectedCategory,
      },
    );
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(
    String text, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              error
                  ? Colors.red
                  : null,

          content:
              Text(text),

          duration:
              const Duration(
            seconds: 4,
          ),
        ),
      );
  }

  // ==========================================================
  // BUILD EDITOR
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_controller ==
        null) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    final availableCategories =
        widget.categories
            .where(
              (category) =>
                  category !=
                  'Все',
            )
            .toList();

    if (!availableCategories
            .contains(
          _selectedCategory,
        ) &&
        availableCategories
            .isNotEmpty) {
      _selectedCategory =
          availableCategories
              .first;
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Редактор',
        ),

        actions: [
          // ====================================================
          // MARKDOWN EXPORT
          // ====================================================

          IconButton(
            tooltip:
                'Экспорт в Markdown',

            icon:
                _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                        ),
                      )
                    : const Icon(
                        Icons
                            .download,
                      ),

            onPressed:
                _saving
                    ? null
                    : _saveToMarkdownFile,
          ),

          // ====================================================
          // SAVE NOTE
          // ====================================================

          IconButton(
            tooltip:
                'Сохранить заметку',

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
          Column(
        children: [
          // ====================================================
          // TITLE
          // ====================================================

          Padding(
            padding:
                const EdgeInsets
                    .fromLTRB(
              12,
              12,
              12,
              4,
            ),

            child:
                TextField(
              controller:
                  _titleController,

              textInputAction:
                  TextInputAction
                      .next,

              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),

              decoration:
                  const InputDecoration(
                labelText:
                    'Название',

                border:
                    OutlineInputBorder(),
              ),
            ),
          ),

          // ====================================================
          // CATEGORY
          // ====================================================

          Padding(
            padding:
                const EdgeInsets
                    .fromLTRB(
              12,
              4,
              12,
              4,
            ),

            child:
                DropdownButtonFormField<
                    String>(
              value:
                  availableCategories
                          .contains(
                        _selectedCategory,
                      )
                      ? _selectedCategory
                      : null,

              decoration:
                  const InputDecoration(
                labelText:
                    'Раздел',

                border:
                    OutlineInputBorder(),
              ),

              items:
                  availableCategories
                      .map(
                        (
                          category,
                        ) {
                          return DropdownMenuItem<
                              String>(
                            value:
                                category,

                            child:
                                Text(
                              category,
                            ),
                          );
                        },
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

          // ====================================================
          // TOOLBAR
          // ====================================================

          const SizedBox(
            height: 4,
          ),

          Material(
            elevation: 2,

            child:
                FleatherToolbar.basic(
              controller:
                  _controller!,
            ),
          ),

          // ====================================================
          // EDITOR
          // ====================================================

          Expanded(
            child:
                Container(
              margin:
                  const EdgeInsets
                      .all(
                8,
              ),

              decoration:
                  BoxDecoration(
                border:
                    Border.all(
                  color: Colors
                      .white24,
                ),

                borderRadius:
                    BorderRadius
                        .circular(
                  8,
                ),
              ),

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
                      _controller!,

                  focusNode:
                      _focusNode,

                  padding:
                      const EdgeInsets
                          .all(
                    8,
                  ),
                ),
              ),
            ),
          ),
        ],
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
