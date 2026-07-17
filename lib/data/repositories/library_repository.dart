import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';

const _uuid = Uuid();

int _now() => DateTime.now().millisecondsSinceEpoch;

/// quill Delta(JSON)에서 미리보기용 평문 텍스트를 추출한다.
String previewFromDelta(String deltaJson, {int maxLength = 300}) {
  try {
    final ops = jsonDecode(deltaJson);
    if (ops is! List) return '';
    final buffer = StringBuffer();
    for (final op in ops) {
      if (op is Map && op['insert'] is String) {
        buffer.write(op['insert']);
        if (buffer.length >= maxLength) break;
      }
    }
    var text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > maxLength) text = text.substring(0, maxLength);
    return text;
  } catch (_) {
    return '';
  }
}

/// 폴더·노트·원본 이미지에 대한 모든 읽기/쓰기를 담당하는 저장소 계층.
class LibraryRepository {
  LibraryRepository(this.db);

  final AppDatabase db;

  // ---------- 폴더 ----------

  Stream<List<Folder>> watchFolders(String? parentId) {
    final q = db.select(db.folders)
      ..where((f) =>
          parentId == null ? f.parentId.isNull() : f.parentId.equals(parentId))
      ..orderBy([(f) => OrderingTerm.asc(f.name)]);
    return q.watch();
  }

  Future<Folder?> getFolder(String id) =>
      (db.select(db.folders)..where((f) => f.id.equals(id))).getSingleOrNull();

  Future<Folder> createFolder(String name, {String? parentId}) async {
    final now = _now();
    final folder = Folder(
      id: _uuid.v4(),
      name: name,
      parentId: parentId,
      createdAt: now,
      updatedAt: now,
    );
    await db.into(db.folders).insert(folder);
    return folder;
  }

  Future<void> renameFolder(String id, String name) =>
      (db.update(db.folders)..where((f) => f.id.equals(id))).write(
          FoldersCompanion(name: Value(name), updatedAt: Value(_now())));

  /// 폴더 삭제: 하위 폴더/노트는 상위 폴더로 이동시킨다.
  Future<void> deleteFolder(String id) async {
    await db.transaction(() async {
      final folder = await getFolder(id);
      if (folder == null) return;
      final parent = Value(folder.parentId);
      await (db.update(db.folders)..where((f) => f.parentId.equals(id)))
          .write(FoldersCompanion(parentId: parent));
      await (db.update(db.notes)..where((n) => n.folderId.equals(id)))
          .write(NotesCompanion(folderId: parent));
      await (db.delete(db.folders)..where((f) => f.id.equals(id))).go();
    });
  }

  // ---------- 노트 ----------

  Stream<List<Note>> watchNotes(String? folderId) {
    final q = db.select(db.notes)
      ..where((n) => Expression.and([
            n.deletedAt.isNull(),
            folderId == null ? n.folderId.isNull() : n.folderId.equals(folderId),
          ]))
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);
    return q.watch();
  }

  Future<Note?> getNote(String id) =>
      (db.select(db.notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<Note> createNote({
    String? folderId,
    List<Uint8List> images = const [],
  }) async {
    final now = _now();
    final note = Note(
      id: _uuid.v4(),
      folderId: folderId,
      title: '',
      textDelta: '[]',
      previewText: '',
      splitRatio: 0.5,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await db.transaction(() async {
      await db.into(db.notes).insert(note);
      var order = 0;
      for (final bytes in images) {
        await db.into(db.noteSources).insert(NoteSource(
              id: _uuid.v4(),
              noteId: note.id,
              kind: 'image',
              bytes: bytes,
              sortOrder: order++,
            ));
      }
    });
    return note;
  }

  Future<void> saveNoteContent(String id, String deltaJson) =>
      (db.update(db.notes)..where((n) => n.id.equals(id))).write(NotesCompanion(
        textDelta: Value(deltaJson),
        previewText: Value(previewFromDelta(deltaJson)),
        updatedAt: Value(_now()),
      ));

  Future<void> saveTitle(String id, String title) =>
      (db.update(db.notes)..where((n) => n.id.equals(id))).write(
          NotesCompanion(title: Value(title), updatedAt: Value(_now())));

  Future<void> saveSplitRatio(String id, double ratio) =>
      (db.update(db.notes)..where((n) => n.id.equals(id)))
          .write(NotesCompanion(splitRatio: Value(ratio)));

  Future<void> moveNote(String id, String? folderId) =>
      (db.update(db.notes)..where((n) => n.id.equals(id))).write(
          NotesCompanion(folderId: Value(folderId), updatedAt: Value(_now())));

  Future<void> deleteNote(String id) =>
      (db.update(db.notes)..where((n) => n.id.equals(id)))
          .write(NotesCompanion(deletedAt: Value(_now())));

  // ---------- 원본(사진) ----------

  Future<List<NoteSource>> getSources(String noteId) =>
      (db.select(db.noteSources)
            ..where((s) => s.noteId.equals(noteId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .get();

  Future<void> addSources(String noteId, List<Uint8List> images) async {
    final existing = await getSources(noteId);
    var order =
        existing.isEmpty ? 0 : existing.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await db.transaction(() async {
      for (final bytes in images) {
        await db.into(db.noteSources).insert(NoteSource(
              id: _uuid.v4(),
              noteId: noteId,
              kind: 'image',
              bytes: bytes,
              sortOrder: order++,
            ));
      }
    });
  }

  Future<void> removeSource(String sourceId) =>
      (db.delete(db.noteSources)..where((s) => s.id.equals(sourceId))).go();
}
