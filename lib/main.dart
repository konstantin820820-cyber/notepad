import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
      ),
      home: const TestEditorScreen(),
    );
  }
}

class TestEditorScreen extends StatefulWidget {
  const TestEditorScreen({super.key});

  @override
  State<TestEditorScreen> createState() =>
      _TestEditorScreenState();
}

class _TestEditorScreenState
    extends State<TestEditorScreen> {
  late FleatherController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    final document = ParchmentDocument(
      heuristics: ParchmentHeuristics.fallback,
    );

    _controller = FleatherController(
      document: document,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест Fleather'),
      ),

      body: SafeArea(
        child: Column(
          children: [
            const Divider(height: 1),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FleatherToolbar.basic(
                controller: _controller,
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FleatherEditor(
                  controller: _controller,
                  focusNode: _focusNode,
                  padding: const EdgeInsets.all(12),
                  expands: true,
                  autofocus: true,
                  showCursor: true,
                  autocorrect: true,
                  enableSuggestions: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}
