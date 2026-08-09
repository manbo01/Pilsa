import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../core/widgets/split_view.dart';
import '../../data/db/database.dart';
import 'image_pages_viewer.dart';

/// 필사 화면: 위/왼쪽 = 책 사진 뷰어, 아래/오른쪽 = 꾸미기 가능한 에디터.
class NoteScreen extends ConsumerStatefulWidget {
  const NoteScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  QuillController? _quill;
  final _titleController = TextEditingController();

  Note? _note;
  List<Uint8List> _images = const [];
  bool _loading = true;
  double _ratio = 0.5;

  Timer? _saveDebounce;
  Timer? _titleDebounce;
  Timer? _ratioDebounce;
  String _lastSavedDelta = '[]';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(libraryRepositoryProvider);
    final note = await repo.getNote(widget.noteId);
    final sources = await repo.getSources(widget.noteId);

    Document document;
    try {
      final ops = jsonDecode(note?.textDelta ?? '[]') as List;
      document = ops.isEmpty ? Document() : Document.fromJson(ops);
    } catch (_) {
      document = Document();
    }

    final controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    controller.document.changes.listen((_) => _scheduleContentSave());

    setState(() {
      _note = note;
      _images = [for (final s in sources) Uint8List.fromList(s.bytes)];
      _quill = controller;
      _titleController.text = note?.title ?? '';
      _ratio = note?.splitRatio ?? 0.5;
      _lastSavedDelta = note?.textDelta ?? '[]';
      _loading = false;
    });
  }

  void _scheduleContentSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _saveContent);
  }

  Future<void> _saveContent() async {
    final quill = _quill;
    if (quill == null) return;
    final delta = jsonEncode(quill.document.toDelta().toJson());
    if (delta == _lastSavedDelta) return;
    setState(() => _saving = true);
    await ref
        .read(libraryRepositoryProvider)
        .saveNoteContent(widget.noteId, delta);
    _lastSavedDelta = delta;
    if (mounted) setState(() => _saving = false);
  }

  void _onTitleChanged(String value) {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(libraryRepositoryProvider).saveTitle(widget.noteId, value.trim());
    });
  }

  void _onRatioChanged(double ratio) {
    setState(() => _ratio = ratio);
    _ratioDebounce?.cancel();
    _ratioDebounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(libraryRepositoryProvider).saveSplitRatio(widget.noteId, ratio);
    });
  }

  Future<void> _addImages() async {
    final files = await ImagePicker().pickMultiImage(limit: 20);
    if (files.isEmpty) return;
    final images = <Uint8List>[];
    for (final f in files) {
      images.add(await f.readAsBytes());
    }
    await ref.read(libraryRepositoryProvider).addSources(widget.noteId, images);
    final sources =
        await ref.read(libraryRepositoryProvider).getSources(widget.noteId);
    if (mounted) {
      setState(() =>
          _images = [for (final s in sources) Uint8List.fromList(s.bytes)]);
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleDebounce?.cancel();
    _ratioDebounce?.cancel();
    // 마지막 변경분 저장(디바운스 미완료분).
    final quill = _quill;
    if (quill != null) {
      final delta = jsonEncode(quill.document.toDelta().toJson());
      if (delta != _lastSavedDelta) {
        ref.read(libraryRepositoryProvider).saveNoteContent(widget.noteId, delta);
      }
      quill.dispose();
    }
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('필사를 찾을 수 없어요')),
      );
    }

    final quill = _quill!;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          onChanged: _onTitleChanged,
          decoration: const InputDecoration(
            hintText: '제목을 입력하세요',
            border: InputBorder.none,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.cloud_done_outlined, size: 18),
            ),
        ],
      ),
      body: SafeArea(
        child: SplitView(
          ratio: _ratio,
          onRatioChanged: _onRatioChanged,
          first: ImagePagesViewer(images: _images, onAddImages: _addImages),
          second: Column(
            children: [
              QuillSimpleToolbar(
                controller: quill,
                config: const QuillSimpleToolbarConfig(
                  multiRowsDisplay: false,
                  showFontFamily: false,
                  showFontSize: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showCodeBlock: false,
                  showInlineCode: false,
                  showLink: false,
                  showSearchButton: false,
                  showIndent: false,
                  showDividers: false,
                  showClipboardCopy: false,
                  showClipboardCut: false,
                  showClipboardPaste: false,
                  buttonOptions: QuillSimpleToolbarButtonOptions(
                    backgroundColor: QuillToolbarColorButtonOptions(
                      iconData: Icons.brush,
                      tooltip: '형광펜',
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: QuillEditor.basic(
                  controller: quill,
                  config: QuillEditorConfig(
                    padding: EdgeInsets.all(16),
                    placeholder: '여기에 필사를 시작하세요…',
                    expands: true,
                    customStyles: DefaultStyles(
                      paragraph: DefaultTextBlockStyle(
                        Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.6) ??
                            const TextStyle(height: 1.6),
                        const HorizontalSpacing(0, 0),
                        const VerticalSpacing(0, 0),
                        const VerticalSpacing(0, 0),
                        null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
