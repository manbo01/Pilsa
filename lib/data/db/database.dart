import 'package:drift/drift.dart';

import 'connection/connection.dart' as impl;

part 'database.g.dart';

/// 폴더 테이블 — 중첩 폴더 지원(자기 참조 parentId).
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 필사 노트 테이블.
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get folderId => text().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();

  /// flutter_quill Delta(JSON) 문자열.
  TextColumn get textDelta => text().withDefault(const Constant('[]'))();

  /// 목록/갤러리 미리보기용 평문 텍스트(저장 시 계산).
  TextColumn get previewText => text().withDefault(const Constant(''))();

  /// 분할 화면 비율(뷰어 영역 비중, 0.15~0.85).
  RealColumn get splitRatio => real().withDefault(const Constant(0.5))();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// 소프트 삭제(추후 동기화 대비).
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 노트에 연결된 원본(책 사진). 노트당 여러 장 지원.
class NoteSources extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();

  /// image | pdf(2단계) | epub(4단계)
  TextColumn get kind => text().withDefault(const Constant('image'))();

  /// 이미지 바이트(모든 플랫폼에서 동일하게 동작하도록 DB BLOB 저장).
  BlobColumn get bytes => blob()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 앱 설정 key-value 저장(테마 모드, 보기 방식 등).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Folders, Notes, NoteSources, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(impl.openConnection());

  /// 테스트용: 메모리 DB 등 임의의 executor 주입.
  AppDatabase.withExecutor(super.e);

  @override
  int get schemaVersion => 1;

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value));
}
