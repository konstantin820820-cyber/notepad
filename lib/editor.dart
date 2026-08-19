import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class EditorScreen extends StatefulWidget {
  final String? id;
  final String? title;
  final String? contentDelta;
  final String? category;
  final List<String> categories;

  const EditorScreen({super.key, this.id, this.title, this.contentDelta, this.category, required this.categories});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  quill.QuillController? _quillController;
  final FocusNode _editorFocusNode = FocusNode();
  String _selectedCategory = 'Личное';

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _titleController.text = widget.title ?? '';
      _selectedCategory = widget.category ?? 'Личное';
      try {
        final doc = quill.Document.fromJson(jsonDecode(widget.contentDelta!));
        _quillController = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
      } catch (_) {
        _quillController = quill.QuillController.basic();
      }
    } else {
      _quillController = quill.QuillController.basic();
      _selectedCategory = widget.categories.contains('Личное') ? 'Личное' : widget.categories.first;
    }
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Новая заметка' : 'Редактирование'),
        actions: [
          DropdownButton<String>(
            value: _selectedCategory,
            underline: const SizedBox(),
            items: widget.categories.where((cat) => cat != 'Все').map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) setState(() { _selectedCategory = newValue; });
            },
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              final contentJson = jsonEncode(_quillController!.document.toDelta().toJson());
              Navigator.pop(context, {
                'title': _titleController.text,
                'contentDelta': contentJson,
                'category': _selectedCategory,
              });
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: 'Заголовок', border: InputBorder.none),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: quill.QuillEditor.basic(
                controller: _quillController!,
                focusNode: _editorFocusNode,
                config: const quill.QuillEditorConfig(
                  placeholder: 'Текст заметки...',
                  autoFocus: true,
                ),
              ),
            ),
          ),
          // Панель в контрастном контейнере с принудительной покраской скрытых иконок
          Container(
            color: const Color(0xFF2C2C2C), // Фиксированный графитовый фон
            child: quill.QuillSimpleToolbar(
              controller: _quillController!,
              config: quill.QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showFontFamily: false,
                showFontSize: false,
                showSubscript: false,
                showSuperscript: false,
                showCodeBlock: false,
                showAlignmentButtons: false,
                showLink: false,
                showSearchButton: false,
                showInlineCode: false,
                showUndo: true,
                showRedo: true,
                showBoldButton: true,
                showItalicButton: true,
                showBackgroundColorButton: true,
                showListBullets: true,
                showListNumbers: true,
                showListCheck: true,
                // Задаем принудительно белый цвет для всех иконок, чтобы они проявились
                buttonOptions: quill.QuillSimpleToolbarButtonOptions(
                  base: quill.QuillToolbarBaseButtonOptions(
                    iconTheme: const quill.QuillIconTheme(
                      iconButtonSelectedData: quill.IconButtonData(color: Colors.amber), // Выбранные - желтые
                      iconButtonUnselectedData: quill.IconButtonData(color: Colors.white), // Обычные - белые
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
