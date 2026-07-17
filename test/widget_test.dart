import 'package:flutter/widgets.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilsa/app/app.dart';
import 'package:pilsa/app/providers.dart';
import 'package:pilsa/data/db/database.dart';

/// drift는 실제 비동기 I/O를 사용하므로 위젯 테스트는 runAsync로 감싼다.
/// 테스트 종료 전 위젯을 실제 시간 영역에서 언마운트해
/// drift 스트림 정리 타이머가 fake-async에 남지 않게 한다.
Future<void> _unmount(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
}

void main() {
  testWidgets('앱이 실행되고 라이브러리 빈 화면이 보인다', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const PilsaApp(),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('필사'), findsOneWidget);
    expect(find.text('아직 필사가 없어요'), findsOneWidget);
    expect(find.text('새 필사'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('폴더와 노트가 목록형 보기에 표시된다', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.runAsync(() async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final library = container.read(libraryRepositoryProvider);
      await library.createFolder('고전문학');
      final note = await library.createNote();
      await library.saveTitle(note.id, '무진기행');
      await library.saveNoteContent(
          note.id, '[{"insert":"안개는 무진의 명산물이다\\n"}]');
      container.dispose();

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const PilsaApp(),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('고전문학'), findsOneWidget);
    expect(find.text('무진기행'), findsOneWidget);
    expect(find.textContaining('안개는 무진의'), findsOneWidget);

    await _unmount(tester);
  });
}
