import 'dart:async';
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
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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

  // ==========================================================
  // ГЛАВНОЕ:
  // содержимое теперь обычный текст.
  // Никакого Delta/JSON внутри Note.
  // ==========================================================

  String content;

  String category;

  bool deleted;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.deleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'deleted': deleted,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    String content = '';

    // --------------------------------------------------------
    // НОВЫЙ ФОРМАТ
    // --------------------------------------------------------

    if (map['content'] != null) {
      content = map['content'].toString();
    }

    // --------------------------------------------------------
    // СОВМЕСТИМОСТЬ СО СТАРОЙ ВЕРСИЕЙ
    //
    // Если старый файл содержит contentJson,
    // пробуем один раз получить из него обычный текст.
    // --------------------------------------------------------

    if (content.isEmpty &&
        map['contentJson'] != null) {
      final oldContent =
          map['contentJson'].toString();

      content =
          _plainTextFromOldContentJson(
        oldContent,
      );
    }

    return Note(
      id: map['id']?.toString() ??
          DateTime.now()
              .microsecondsSinceEpoch
              .toString(),

      title:
          map['title']?.toString() ?? '',

      content: content,

      category:
          map['category']?.toString() ??
              'Личное',

      deleted:
          map['deleted'] == true ||
              map['deleted']?.toString() ==
                  'true',
    );
  }

  static String _plainTextFromOldContentJson(
    String value,
  ) {
    try {
      final decoded =
          jsonDecode(value);

      if (decoded is List) {
        final buffer =
            StringBuffer();

        for (final item in decoded) {
          if (item is Map &&
              item['insert'] != null) {
            buffer.write(
              item['insert'].toString(),
            );
          }
        }

        return buffer.toString();
      }
    } catch (_) {}

    return value;
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

  List<String> _categories = [
    'Все',
    'Личное',
    'Работа',
    'Идеи',
    'Покупки',
  ];

  TabController? _tabController;

  bool _loading = true;

  bool _showTrash = false;

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
        await SharedPreferences
            .getInstance();

    final savedCategories =
        prefs.getStringList(
      'local_categories',
    );

    final notesString =
        prefs.getString(
      'local_notes_clean',
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
      } catch (_) {
        notes = [];
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
      length:
          categories.length,
      vsync: this,
    );

    _tabController!.addListener(
      () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _categories =
          categories;

      _notes =
          notes;

      _loading =
          false;
    });

    // --------------------------------------------------------
    // Сохраняем старые заметки уже в новом формате.
    // --------------------------------------------------------

    await _saveData();
  }

  // ==========================================================
  // SAVE DATA
  // ==========================================================

  Future<void> _saveData() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setStringList(
      'local_categories',
      _categories,
    );

    await prefs.setString(
      'local_notes_clean',
      jsonEncode(
        _notes
            .map(
              (note) =>
                  note.toMap(),
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
      length:
          _categories.length,
      vsync: this,
    );

    final safeIndex =
        selectedIndex.clamp(
      0,
      _categories.length - 1,
    );

    _tabController!.index =
        safeIndex;

    _tabController!.addListener(
      () {
        if (mounted) {
          setState(() {});
        }
      },
    );

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
      builder:
          (context) {
        return AlertDialog(
          title:
              const Text(
            'Новый раздел',
          ),
          content:
              TextField(
            controller:
                controller,
            autofocus:
                true,
            textCapitalization:
                TextCapitalization
                    .sentences,
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
              onPressed:
                  () {
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
              onPressed:
                  () {
                final value =
                    controller
                        .text
                        .trim();

                if (value
                    .isNotEmpty) {
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

    if (_categories
        .contains(newName)) {
      _showMessage(
        'Такой раздел уже существует',
      );
      return;
    }

    setState(() {
      _categories
          .add(newName);
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
      builder:
          (context) {
        return AlertDialog(
          title:
              const Text(
            'Переименовать раздел',
          ),
          content:
              TextField(
            controller:
                controller,
            autofocus:
                true,
            textCapitalization:
                TextCapitalization
                    .sentences,
          ),
          actions: [
            TextButton(
              onPressed:
                  () {
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
              onPressed:
                  () {
                final value =
                    controller
                        .text
                        .trim();

                if (value
                    .isNotEmpty) {
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

    if (_categories
        .contains(trimmed)) {
      _showMessage(
        'Такой раздел уже существует',
      );
      return;
    }

    setState(() {
      final index =
          _categories
              .indexOf(category);

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
        _categories
            .indexOf(trimmed);

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
                  !n.deleted &&
                  n.category ==
                      category,
            )
            .length;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder:
          (context) {
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
      _categories
          .remove(category);

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
        (_tabController
                    ?.index ??
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
      isScrollControlled:
          true,
      builder:
          (context) {
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
                        )
                        .size
                        .height *
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
                              FontWeight
                                  .bold,
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
                                .all(
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
                              oldIndex +
                                  1;

                          final toIndex =
                              newIndex +
                                  1;

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
                              .all(
                        16,
                      ),
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
            ? _notes
                .where(
                  (n) =>
                      !n.deleted,
                )
                .toList()
            : _notes
                .where(
                  (n) =>
                      !n.deleted &&
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
        visibleNotes
            .removeAt(
      oldIndex,
    );

    visibleNotes.insert(
      newIndex,
      moved,
    );

    setState(() {
      if (category == 'Все') {
        final active =
            _notes
                .where(
                  (n) =>
                      !n.deleted,
                )
                .toList();

        for (int i = 0;
            i < active.length;
            i++) {
          active[i] =
              visibleNotes[i];
        }

        int index = 0;

        for (int i = 0;
            i < _notes.length;
            i++) {
          if (!_notes[i]
              .deleted) {
            _notes[i] =
                active[index];
            index++;
          }
        }
      } else {
        int visibleIndex =
            0;

        for (int i = 0;
            i < _notes.length;
            i++) {
          if (!_notes[i].deleted &&
              _notes[i].category ==
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
  // ADD NOTE
  // ==========================================================

  Future<void> _addNote() async {
    final currentIndex =
        _tabController
                ?.index ??
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
        await Navigator.push<
            Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
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

    final newNote =
        Note(
      id: DateTime.now()
          .microsecondsSinceEpoch
          .toString(),
      title:
          result['title']
                  ?.toString() ??
              '',
      content:
          result['content']
                  ?.toString() ??
              '',
      category:
          result['category']
                  ?.toString() ??
              defaultCategory,
    );

    setState(() {
      _notes.add(
        newNote,
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
        await Navigator.push<
            Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
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
        (n) =>
            n.id == note.id,
      );

      if (index != -1) {
        _notes[index]
          ..title =
              result['title']
                      ?.toString() ??
                  ''
          ..content =
              result['content']
                      ?.toString() ??
                  ''
          ..category =
              result['category']
                      ?.toString() ??
                  note.category;
      }
    });

    await _saveData();
  }

  // ==========================================================
  // MOVE TO TRASH
  // ==========================================================

  Future<void> _moveToTrash(
    Note note,
  ) async {
    setState(() {
      note.deleted =
          true;
    });

    await _saveData();

    _showMessage(
      'Заметка перемещена в корзину',
    );
  }

  // ==========================================================
  // RESTORE NOTE
  // ==========================================================

  Future<void> _restoreNote(
    Note note,
  ) async {
    setState(() {
      note.deleted =
          false;
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
      builder:
          (context) {
        return AlertDialog(
          title:
              const Text(
            'Удалить навсегда?',
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

    if (confirmed !=
        true) {
      return;
    }

    setState(() {
      _notes.removeWhere(
        (n) =>
            n.id == note.id,
      );
    });

    await _saveData();
  }

  // ==========================================================
  // EMPTY TRASH
  // ==========================================================

  Future<void> _emptyTrash() async {
    final trashCount =
        _notes
            .where(
              (n) =>
                  n.deleted,
            )
            .length;

    if (trashCount == 0) {
      _showMessage(
        'Корзина уже пуста',
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder:
          (context) {
        return AlertDialog(
          title:
              const Text(
            'Очистить корзину?',
          ),
          content:
              Text(
            'Будет окончательно удалено '
            '$trashCount заметок.',
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
                'Очистить',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed !=
        true) {
      return;
    }

    setState(() {
      _notes.removeWhere(
        (n) =>
            n.deleted,
      );
    });

    await _saveData();

    _showMessage(
      'Корзина очищена',
    );
  }

  // ==========================================================
  // TRASH SCREEN
  // ==========================================================

  Widget _buildTrash() {
    final trash =
        _notes
            .where(
              (n) =>
                  n.deleted,
            )
            .toList();

    if (trash.isEmpty) {
      return Center(
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .delete_outline,
              size: 64,
              color:
                  Colors.white
                      .withOpacity(
                0.25,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              'Корзина пуста',
              style:
                  TextStyle(
                color:
                    Colors.white
                        .withOpacity(
                  0.55,
                ),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding:
          const EdgeInsets.fromLTRB(
        10,
        10,
        10,
        90,
      ),
      itemCount:
          trash.length,
      itemBuilder:
          (context, index) {
        final note =
            trash[index];

        return Card(
          margin:
              const EdgeInsets
                  .only(
            bottom: 8,
          ),
          child:
              ListTile(
            contentPadding:
                const EdgeInsets
                    .symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading:
                const Icon(
              Icons
                  .delete_outline,
              color:
                  Colors.redAccent,
            ),
            title:
                Text(
              note.title.isEmpty
                  ? 'Без названия'
                  : note.title,
              maxLines:
                  1,
              overflow:
                  TextOverflow
                      .ellipsis,
            ),
            subtitle:
                Text(
              note.content
                      .replaceAll(
                        '\n',
                        ' ',
                      )
                      .trim()
                      .isEmpty
                  ? 'Пустая заметка'
                  : note.content
                      .replaceAll(
                        '\n',
                        ' ',
                      )
                      .trim(),
              maxLines:
                  2,
              overflow:
                  TextOverflow
                      .ellipsis,
            ),
            trailing:
                PopupMenuButton<
                    String>(
              onSelected:
                  (value) async {
                if (value ==
                    'restore') {
                  await _restoreNote(
                    note,
                  );
                }

                if (value ==
                    'delete') {
                  await _deleteForever(
                    note,
                  );
                }
              },
              itemBuilder:
                  (context) =>
                      const [
                PopupMenuItem(
                  value:
                      'restore',
                  child:
                      Row(
                    children: [
                      Icon(
                        Icons
                            .restore,
                      ),
                      SizedBox(
                        width:
                            8,
                      ),
                      Text(
                        'Восстановить',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value:
                      'delete',
                  child:
                      Row(
                    children: [
                      Icon(
                        Icons
                            .delete_forever,
                        color:
                            Colors
                                .red,
                      ),
                      SizedBox(
                        width:
                            8,
                      ),
                      Text(
                        'Удалить навсегда',
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
  }

  // ==========================================================
  // NOTE PREVIEW
  // ==========================================================

  String _previewText(
    String text,
  ) {
    final value =
        text.trim();

    if (value.isEmpty) {
      return 'Пустая заметка';
    }

    return value;
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
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading ||
        _tabController ==
            null) {
      return const Scaffold(
        body:
            Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_showTrash) {
      return Scaffold(
        appBar:
            AppBar(
          title:
              const Text(
            'Корзина',
          ),
          leading:
              IconButton(
            icon:
                const Icon(
              Icons
                  .arrow_back,
            ),
            onPressed:
                () {
              setState(() {
                _showTrash =
                    false;
              });
            },
          ),
          actions: [
            IconButton(
              tooltip:
                  'Очистить корзину',
              icon:
                  const Icon(
                Icons
                    .delete_sweep_outlined,
              ),
              onPressed:
                  _emptyTrash,
            ),
          ],
        ),
        body:
            _buildTrash(),
      );
    }

    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'Мой Блокнот',
          style:
              TextStyle(
            fontWeight:
                FontWeight
                    .w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip:
                'Корзина',
            icon:
                const Icon(
              Icons
                  .delete_outline,
            ),
            onPressed:
                () {
              setState(() {
                _showTrash =
                    true;
              });
            },
          ),
          IconButton(
            tooltip:
                'Разделы',
            icon:
                const Icon(
              Icons
                  .folder_open_outlined,
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
                    (
                      category,
                    ) =>
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
            _categories
                .map(
          (
            category,
          ) {
            final filteredNotes =
                category ==
                        'Все'
                    ? _notes
                        .where(
                          (n) =>
                              !n.deleted,
                        )
                        .toList()
                    : _notes
                        .where(
                          (n) =>
                              !n.deleted &&
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
                      MainAxisSize
                          .min,
                  children: [
                    Icon(
                      Icons
                          .note_alt_outlined,
                      size: 56,
                      color:
                          Colors.white
                              .withOpacity(
                        0.22,
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
                          0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding:
                  const EdgeInsets
                      .all(
                8,
              ),
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
                      0.92,
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

                  return _buildNoteCard(
                    note,
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
  // NOTE CARD
  // ==========================================================

  Widget _buildNoteCard(
    Note note,
  ) {
    return Card(
      key:
          ValueKey(
        note.id,
      ),
      clipBehavior:
          Clip.antiAlias,
      child:
          InkWell(
        onTap:
            () {
          _editNote(
            note,
          );
        },
        child:
            Padding(
          padding:
              const EdgeInsets
                  .all(
            14,
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
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight
                                .w600,
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
                        await _moveToTrash(
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
              const SizedBox(
                height: 8,
              ),
              Expanded(
                child:
                    Text(
                  _previewText(
                    note.content,
                  ),
                  style:
                      TextStyle(
                    fontSize:
                        14,
                    height:
                        1.35,
                    color:
                        Colors.white
                            .withOpacity(
                      0.75,
                    ),
                  ),
                  maxLines:
                      8,
                  overflow:
                      TextOverflow
                          .fade,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Row(
                children: [
                  Icon(
                    Icons
                        .folder_outlined,
                    size:
                        14,
                    color:
                        Colors.amber
                            .withOpacity(
                      0.8,
                    ),
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Expanded(
                    child:
                        Text(
                      note.category,
                      style:
                          TextStyle(
                        fontSize:
                            11,
                        color:
                            Colors.amber
                                .withOpacity(
                          0.85,
                        ),
                      ),
                      maxLines:
                          1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                  ),
                ],
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
    _tabController
        ?.dispose();

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

  final FocusNode _focusNode =
      FocusNode();

  late FleatherController
      _controller;

  late String
      _selectedCategory;

  Timer? _autoSaveTimer;

  bool _saving =
      false;

  bool _initializing =
      true;

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

    _controller.addListener(
      _onEditorChanged,
    );

    _titleController
        .addListener(
      _onEditorChanged,
    );

    _initializing =
        false;
  }

  // ==========================================================
  // CATEGORY
  // ==========================================================

  String _getInitialCategory() {
    if (widget.note !=
        null) {
      _titleController
          .text =
          widget.note!.title;

      if (widget.categories
          .contains(
        widget.note!.category,
      )) {
        return widget
            .note!.category;
      }
    }

    final available =
        widget.categories
            .where(
              (c) =>
                  c != 'Все',
            )
            .toList();

    if (widget.initialCategory !=
            null &&
        available.contains(
          widget.initialCategory,
        )) {
      return widget
          .initialCategory!;
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
  // CREATE FLEATHER CONTROLLER
  //
  // Здесь обычный текст превращается во временный Delta,
  // только для работы Fleather.
  //
  // В Note он НЕ сохраняется.
  // ==========================================================

  FleatherController
      _createController() {
    final text =
        widget.note?.content ??
            '';

    if (text.isEmpty) {
      return FleatherController();
    }

    try {
      final delta =
          [
        {
          'insert':
              text.endsWith('\n')
                  ? text
                  : '$text\n',
        },
      ];

      final document =
          ParchmentDocument
              .fromJson(
        delta,
      );

      return FleatherController(
        document:
            document,
      );
    } catch (_) {
      return FleatherController();
    }
  }

  // ==========================================================
  // GET PLAIN TEXT
  // ==========================================================

  String _getPlainText() {
    try {
      return _controller
          .document
          .toPlainText();
    } catch (_) {
      return '';
    }
  }

  // ==========================================================
  // EDITOR CHANGED
  // ==========================================================

  void _onEditorChanged() {
    if (_initializing ||
        !mounted) {
      return;
    }

    _autoSaveTimer?.cancel();

    _autoSaveTimer =
        Timer(
      const Duration(
        milliseconds: 500,
      ),
      _autoSave,
    );
  }

  // ==========================================================
  // AUTO SAVE
  // ==========================================================

  Future<void> _autoSave() async {
    if (_saving ||
        !mounted) {
      return;
    }

    if (widget.note ==
        null) {
      return;
    }

    _saving = true;

    try {
      final text =
          _getPlainText();

      widget.note!
        ..title =
            _titleController
                .text
                .trim()
        ..content =
            text
        ..category =
            _selectedCategory;
    } finally {
      _saving = false;
    }
  }

  // ==========================================================
  // SAVE AND CLOSE
  // ==========================================================

  Future<void> _saveNote() async {
    _autoSaveTimer?.cancel();

    final title =
        _titleController
            .text
            .trim();

    final content =
        _getPlainText();

    Navigator.pop(
      context,
      {
        'title':
            title,
        'content':
            content,
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
          _titleController
              .text
              .trim();

      final content =
          _getPlainText();

      final safeTitle =
          _safeFileName(
        title.isEmpty
            ? 'untitled_note'
            : title,
      );

      final fileName =
          '$safeTitle.txt';

      final tempDirectory =
          Directory
              .systemTemp;

      final tempFile =
          File(
        '${tempDirectory.path}/'
        '${DateTime.now().microsecondsSinceEpoch}_'
        '$fileName',
      );

      // ======================================================
      // ВАЖНО:
      // записываем именно обычный текст.
      //
      // Никакого JSON.
      // Никакого Markdown.
      // Никакого Delta.
      // ======================================================

      await tempFile.writeAsString(
        content,
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

      if (savedPath !=
              null &&
          savedPath
              .isNotEmpty) {
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
                FontWeight.w600,
          ),
          decoration:
              const InputDecoration(
            hintText:
                'Название',
            border:
                InputBorder.none,
          ),
          textInputAction:
              TextInputAction.done,
        ),
        actions: [
          // --------------------------------------------------
          // EXPORT TXT
          // --------------------------------------------------

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

          // --------------------------------------------------
          // CLOSE / SAVE
          // --------------------------------------------------

          IconButton(
            tooltip:
                'Готово',
            icon:
                const Icon(
              Icons.check,
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
            // ------------------------------------------------
            // CATEGORY
            // ------------------------------------------------

            Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                12,
                6,
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
                                    .contains(
                          _selectedCategory,
                        )
                                ? _selectedCategory
                                : null,
                        isExpanded:
                            true,
                        items:
                            widget
                                .categories
                                .where(
                                  (
                                    category,
                                  ) =>
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

                          _onEditorChanged();
                        },
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

            // ------------------------------------------------
            // TOOLBAR
            // ------------------------------------------------

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

            // ------------------------------------------------
            // EDITOR
            // ------------------------------------------------

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
                      widget.note ==
                          null,
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
    _autoSaveTimer?.cancel();

    _focusNode.dispose();

    _controller.dispose();

    _titleController
        .dispose();

    super.dispose();
  }
}
