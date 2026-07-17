import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// iOS/Android/데스크톱: 앱 문서 디렉토리의 SQLite 파일 사용.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pilsa.db'));
    return NativeDatabase.createInBackground(file);
  });
}
