import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../settings/settings_providers.dart';

/// 홈 화면: 폴더 탐색 + 필사 목록(목록형/갤러리형).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, this.folderId});

  final String? folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider(folderId));
    final notes = ref.watch(notesProvider(folderId));
    final gallery = ref.watch(galleryViewProvider);
    final currentFolder =
        folderId == null ? null : ref.watch(folderProvider(folderId!));

    final title = folderId == null
      ? 'PILSA'
      : (currentFolder?.value?.name ?? '폴더');

    return Scaffold(
      appBar: AppBar(
        leading: folderId == null
            ? null
            : BackButton(onPressed: () => _goUp(context, ref)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
          ],
        ),
        actions: [
          IconButton(
            tooltip: gallery ? '목록형 보기' : '갤러리형 보기',
            icon: Icon(gallery ? Icons.view_list_outlined : Icons.grid_view_outlined),
            onPressed: () =>
                ref.read(galleryViewProvider.notifier).set(!gallery),
          ),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(context, ref),
        tooltip: '새 필사',
        child: Stack(
          alignment: Alignment.center,
          children: const [
            Icon(Icons.menu_book_outlined, size: 24),
            Positioned(
              right: 6,
              bottom: 6,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Colors.white,
                child: Icon(Icons.add, size: 12, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
      body: folders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (folderList) => notes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
          data: (noteList) {
            if (folderList.isEmpty && noteList.isEmpty) {
              return const _EmptyView();
            }
            return gallery
                ? _GalleryView(folders: folderList, notes: noteList)
                : _ListView(folders: folderList, notes: noteList);
          },
        ),
      ),
    );
  }

  Future<void> _goUp(BuildContext context, WidgetRef ref) async {
    final folder =
        await ref.read(libraryRepositoryProvider).getFolder(folderId!);
    if (!context.mounted) return;
    final parent = folder?.parentId;
    context.go(parent == null ? '/' : '/?folder=$parent');
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('책 사진으로 새 필사'),
              subtitle: const Text('사진을 여러 장 선택할 수 있어요'),
              onTap: () {
                Navigator.pop(sheetContext);
                _createNoteFromPhotos(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('사진 없이 새 필사'),
              onTap: () {
                Navigator.pop(sheetContext);
                _createNote(context, ref, const []);
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('새 폴더'),
              onTap: () {
                Navigator.pop(sheetContext);
                _createFolder(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNoteFromPhotos(
      BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(limit: 20);
    if (files.isEmpty) return;
    final images = <Uint8List>[];
    for (final f in files) {
      images.add(await f.readAsBytes());
    }
    if (!context.mounted) return;
    await _createNote(context, ref, images);
  }

  Future<void> _createNote(
      BuildContext context, WidgetRef ref, List<Uint8List> images) async {
    final note = await ref
        .read(libraryRepositoryProvider)
        .createNote(folderId: folderId, images: images);
    if (context.mounted) context.push('/note/${note.id}');
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final name = await _promptText(context, title: '새 폴더', hint: '폴더 이름');
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(libraryRepositoryProvider)
        .createFolder(name.trim(), parentId: folderId);
  }
}

Future<String?> _promptText(BuildContext context,
    {required String title, String? hint, String? initial}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('확인')),
      ],
    ),
  );
}

String _formatDate(int millis) {
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return DateFormat('HH:mm').format(date);
  }
  return DateFormat('yyyy.MM.dd').format(date);
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: color),
          const SizedBox(height: 16),
          Text('아직 필사가 없어요',
              style: TextStyle(fontSize: 16, color: color)),
          const SizedBox(height: 4),
          Text('아래 [새 필사] 버튼으로 시작해 보세요',
              style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

// ---------- 목록형 ----------

class _ListView extends ConsumerWidget {
  const _ListView({required this.folders, required this.notes});

  final List<Folder> folders;
  final List<Note> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final folder in folders)
          ListTile(
            leading: Icon(Icons.folder_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: Text(folder.name),
            onTap: () => context.go('/?folder=${folder.id}'),
            onLongPress: () => showFolderActions(context, ref, folder),
          ),
        if (folders.isNotEmpty && notes.isNotEmpty) const Divider(height: 1),
        for (final note in notes)
          ListTile(
            leading: const Icon(Icons.history_edu_outlined),
            title: Text(
              note.title.isEmpty ? '제목 없음' : note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: note.previewText.isEmpty
                ? null
                : Text(note.previewText,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(_formatDate(note.updatedAt),
                style: Theme.of(context).textTheme.bodySmall),
            onTap: () => context.push('/note/${note.id}'),
            onLongPress: () => showNoteActions(context, ref, note),
          ),
      ],
    );
  }
}

// ---------- 갤러리형 (필사 글 미리보기 카드) ----------

class _GalleryView extends ConsumerWidget {
  const _GalleryView({required this.folders, required this.notes});

  final List<Folder> folders;
  final List<Note> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        if (folders.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final folder in folders)
                    ActionChip(
                      avatar: Icon(Icons.folder_outlined,
                          size: 18, color: scheme.primary),
                      label: Text(folder.name),
                      onPressed: () => context.go('/?folder=${folder.id}'),
                    ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final note = notes[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  color: scheme.surfaceContainerLow,
                  child: InkWell(
                    onTap: () => context.push('/note/${note.id}'),
                    onLongPress: () => showNoteActions(context, ref, note),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title.isEmpty ? '제목 없음' : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              note.previewText.isEmpty
                                  ? '아직 내용이 없어요'
                                  : note.previewText,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: note.previewText.isEmpty
                                          ? scheme.outline
                                          : null,
                                      height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_formatDate(note.updatedAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: scheme.outline)),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: notes.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- 길게 눌러 열리는 작업 메뉴 ----------

Future<void> showNoteActions(
    BuildContext context, WidgetRef ref, Note note) async {
  final repo = ref.read(libraryRepositoryProvider);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('제목 바꾸기'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final name = await _promptText(context,
                  title: '제목 바꾸기', initial: note.title);
              if (name != null) await repo.saveTitle(note.id, name.trim());
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('삭제'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final ok = await _confirm(context, '이 필사를 삭제할까요?');
              if (ok) await repo.deleteNote(note.id);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> showFolderActions(
    BuildContext context, WidgetRef ref, Folder folder) async {
  final repo = ref.read(libraryRepositoryProvider);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('이름 바꾸기'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final name = await _promptText(context,
                  title: '폴더 이름 바꾸기', initial: folder.name);
              if (name != null && name.trim().isNotEmpty) {
                await repo.renameFolder(folder.id, name.trim());
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('폴더 삭제'),
            subtitle: const Text('안의 필사와 폴더는 상위로 이동합니다'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final ok = await _confirm(context, '이 폴더를 삭제할까요?');
              if (ok) await repo.deleteFolder(folder.id);
            },
          ),
        ],
      ),
    ),
  );
}

Future<bool> _confirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제')),
      ],
    ),
  );
  return result ?? false;
}
