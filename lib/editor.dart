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

  // Общая функция для вставки обычных стилей (жирный, курсив, маркер)
  void _insertStyle(String openTag, String closeTag) {
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

  // УМНАЯ ЛОГИКА ДЛЯ СПИСКОВ И КНОПОК НАВЕРХУ КЛАВИАТУРЫ
  void _insertBlockStructure(String type) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final int cursorPosition = selection.baseOffset == -1 ? text.length : selection.baseOffset;

    // Определяем, находится ли курсор в начале новой строки
    bool isStartOfLine = cursorPosition == 0 || text.codeUnitAt(cursorPosition - 1) == 10; // 10 — код символа \n
    String prefix = isStartOfLine ? "" : "\n";

    String marker = "";
    if (type == 'bullet') {
      marker = "• ";
    } else if (type == 'checkbox') {
      marker = "[ ] ";
    } else if (type == 'number') {
      // Умный поиск предыдущего номера строки для автоинкремента
      int nextNumber = 1;
      final textBeforeCursor = text.substring(0, cursorPosition);
      final lines = textBeforeCursor.split('\n');
      if (lines.isNotEmpty) {
        for (int i = lines.length - 1; i >= 0; i--) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          final match = RegExp(r'^(\d+)\.').firstMatch(line);
          if (match != null) {
            nextNumber = int.parse(match.group(1)!) + 1;
            break;
          }
        }
      }
      marker = "$nextNumber. ";
    }

    final String insertion = "$prefix$marker";
    final newText = text.replaceRange(cursorPosition, cursorPosition, insertion);
    
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(offset: cursorPosition + insertion.length);
  }

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
          // ПАНЕЛЬ ИНСТРУМЕНТОВ
          Container(
            color: const Color(0xFF333333),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(icon: const Icon(Icons.format_bold, color: Colors.white), onPressed: () => _insertStyle('**', '**')),
                IconButton(icon: const Icon(Icons.format_italic, color: Colors.white), onPressed: () => _insertStyle('*', '*')),
                IconButton(icon: const Icon(Icons.border_color, color: Colors.white), onPressed: () => _insertStyle('==', '==')), // Чистый Markdown маркер
                IconButton(icon: const Icon(Icons.format_list_bulleted, color: Colors.white), onPressed: () => _insertBlockStructure('bullet')),
                IconButton(icon: const Icon(Icons.format_list_numbered, color: Colors.white), onPressed: () => _insertBlockStructure('number')),
                IconButton(icon: const Icon(Icons.check_box_outlined, color: Colors.white), onPressed: () => _insertBlockStructure('checkbox')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
