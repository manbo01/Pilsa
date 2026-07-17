import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/repositories/library_repository.dart';

/// 앱 전역 DB 인스턴스. 테스트에서는 overrideWithValue로 교체한다.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final libraryRepositoryProvider = Provider<LibraryRepository>(
    (ref) => LibraryRepository(ref.watch(databaseProvider)));

final foldersProvider = StreamProvider.family<List<Folder>, String?>(
    (ref, parentId) =>
        ref.watch(libraryRepositoryProvider).watchFolders(parentId));

final notesProvider = StreamProvider.family<List<Note>, String?>((ref,
        folderId) =>
    ref.watch(libraryRepositoryProvider).watchNotes(folderId));

final folderProvider = FutureProvider.family<Folder?, String>(
    (ref, id) => ref.watch(libraryRepositoryProvider).getFolder(id));
