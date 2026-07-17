import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilsa/data/db/database.dart';
import 'package:pilsa/data/repositories/library_repository.dart';

void main() {
  late AppDatabase db;
  late LibraryRepository repo;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    repo = LibraryRepository(db);
  });

  tearDown(() => db.close());

  group('폴더', () {
    test('생성/이름변경/삭제(내용은 상위로 이동)', () async {
      final folder = await repo.createFolder('고전');
      final child = await repo.createFolder('한국문학', parentId: folder.id);
      final note = await repo.createNote(folderId: child.id);

      await repo.renameFolder(folder.id, '고전문학');
      expect((await repo.getFolder(folder.id))!.name, '고전문학');

      // 하위 폴더 삭제 → 노트가 상위 폴더로 이동
      await repo.deleteFolder(child.id);
      final moved = await repo.getNote(note.id);
      expect(moved!.folderId, folder.id);

      // 루트 폴더 삭제 → 노트가 루트로 이동
      await repo.deleteFolder(folder.id);
      expect((await repo.getNote(note.id))!.folderId, isNull);
    });

    test('루트/하위 폴더 목록 스트림', () async {
      await repo.createFolder('A');
      final b = await repo.createFolder('B');
      await repo.createFolder('B-1', parentId: b.id);

      expect((await repo.watchFolders(null).first).length, 2);
      expect((await repo.watchFolders(b.id).first).length, 1);
    });
  });

  group('노트', () {
    test('사진과 함께 생성하고 원본을 읽는다', () async {
      final img1 = Uint8List.fromList([1, 2, 3]);
      final img2 = Uint8List.fromList([4, 5, 6]);
      final note = await repo.createNote(images: [img1, img2]);

      final sources = await repo.getSources(note.id);
      expect(sources.length, 2);
      expect(sources[0].sortOrder, 0);
      expect(sources[1].sortOrder, 1);
      expect(sources[0].bytes, img1);
    });

    test('사진 추가 시 sortOrder가 이어진다', () async {
      final note =
          await repo.createNote(images: [Uint8List.fromList([1])]);
      await repo.addSources(note.id, [Uint8List.fromList([2])]);
      final sources = await repo.getSources(note.id);
      expect(sources.map((s) => s.sortOrder), [0, 1]);
    });

    test('내용 저장 시 미리보기 텍스트가 갱신된다', () async {
      final note = await repo.createNote();
      const delta =
          '[{"insert":"산다는 것은 "},{"insert":"견디는","attributes":{"bold":true}},{"insert":" 것이다\\n"}]';
      await repo.saveNoteContent(note.id, delta);

      final saved = await repo.getNote(note.id);
      expect(saved!.textDelta, delta);
      expect(saved.previewText, '산다는 것은 견디는 것이다');
      expect(saved.updatedAt, greaterThanOrEqualTo(note.updatedAt));
    });

    test('소프트 삭제하면 목록에서 사라진다', () async {
      final note = await repo.createNote();
      expect((await repo.watchNotes(null).first).length, 1);
      await repo.deleteNote(note.id);
      expect((await repo.watchNotes(null).first).length, 0);
      // 데이터 자체는 남아 있다(동기화 대비 소프트 삭제).
      expect(await repo.getNote(note.id), isNotNull);
    });

    test('분할 비율과 제목 저장', () async {
      final note = await repo.createNote();
      await repo.saveTitle(note.id, '무진기행');
      await repo.saveSplitRatio(note.id, 0.42);
      final saved = await repo.getNote(note.id);
      expect(saved!.title, '무진기행');
      expect(saved.splitRatio, closeTo(0.42, 1e-9));
    });
  });

  group('previewFromDelta', () {
    test('공백 정리와 길이 제한', () {
      expect(previewFromDelta('[{"insert":"a\\n\\nb   c\\n"}]'), 'a b c');
      expect(previewFromDelta('잘못된 json'), '');
      final long = '[{"insert":"${'가' * 500}"}]';
      expect(previewFromDelta(long).length, 300);
    });
  });

  group('설정', () {
    test('key-value 저장/갱신', () async {
      expect(await db.getSetting('themeMode'), isNull);
      await db.setSetting('themeMode', 'dark');
      expect(await db.getSetting('themeMode'), 'dark');
      await db.setSetting('themeMode', 'light');
      expect(await db.getSetting('themeMode'), 'light');
    });
  });
}
