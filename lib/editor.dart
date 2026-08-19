import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorScreen extends StatefulWidget {
  final String? id;
  final String? title;
  final String? content;
  final String? category;
  final List<String> categories;

  const EditorScreen({super.key, this.id, this.title, this.content, this.category, required this.categories});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedCategory = 'Личное';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.title ?? '';
    _contentController.text = widget.content ?? '';
    if (widget.category != null && widget.categories.contains(widget.category)) {
      _selectedCategory = widget.category!;
    } else {
      _selectedCategory = widget.categories.contains('Личное') ? 'Личное' : widget.categories.first;
    }
  }

  void _insertMarkup(String openTag, String closeTag) {
    final text = _contentController.text;
    final selection = _contentController.selection;

    if (selection.start == -1 || selection.end == -1) {
      final currentOffset = text.length;
      final newText = text + openTag + closeTag;
      _contentController.text = newText;
      _contentController.selection = TextSelection.collapsed(offset: currentOffset + openTag.length);
      return;
    }

    final selectedText = selection.textInside(text);
    final newText = text.replaceRange(selection.start, selection.end, '$openTag$selectedText$closeTag');
    
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + openTag.length + selectedText.length + closeTag.length,
    );
  }

  // НАВНАЯ И БЕЗОПАСНАЯ ЛОГИКА КОПИРОВАНИЯ В БУФЕР ТЕЛЕФОНА
  void _copyToClipboard() {
    final String fullText = "${_titleController.text}\n\n${_contentController.text}";
    Clipboard.setData(ClipboardData(text: fullText)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Текст заметки скопирован в буфер обмена!')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Новая заметка' : 'Редактирование'),
        actions: [
          IconButton(icon: const Icon(Icons.copy), onPressed: _copyToClipboard, tooltip: 'Копировать текст'),
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
              Navigator.pop(context, {
                'title': _titleController.text,
                'content': _contentController.text,
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
              child: TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(hintText: 'Текст заметки...', border: InputBorder.none),
              ),
            ),
          ),
          Container(
            color: const Color(0xFF333333),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(icon: const Icon(Icons.format_bold, color: Colors.white), onPressed: () => _insertMarkup('**', '**')),
                IconButton(icon: const Icon(Icons.format_italic, color: Colors.white), onPressed: () => _insertMarkup('*', '*')),
                IconButton(icon: const Icon(Icons.border_color, color: Colors.white), onPressed: () => _insertMarkup('<bg>', '</bg>')),
                IconButton(icon: const Icon(Icons.format_list_bulleted, color: Colors.white), onPressed: () => _insertMarkup('\n- ', '')),
                IconButton(icon: const Icon(Icons.format_list_numbered, color: Colors.white), onPressed: () => _insertMarkup('\n1. ', '')),
                IconButton(icon: const Icon(Icons.check_box_outlined, color: Colors.white), onPressed: () => _insertMarkup('\n[ ] ', '')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
