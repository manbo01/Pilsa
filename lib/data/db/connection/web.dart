// 웹: sql.js 기반 drift 웹 스토리지(IndexedDB 영속화).
//
// 참고: drift의 최신 웹 방식(WasmDatabase + sqlite3.wasm)이 권장되지만,
// sqlite3.wasm 파일을 이 빌드 환경에서 받을 수 없어 우선 sql.js를 사용한다.
// 교체 방법은 docs/개발노트를 참고 (web/sqlite3.wasm + drift_worker.js 배치 후
// WasmDatabase.open으로 전환).
// ignore_for_file: deprecated_member_use

import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final storage = await DriftWebStorage.indexedDbIfSupported('pilsa_db');
    return WebDatabase.withStorage(storage);
  });
}
