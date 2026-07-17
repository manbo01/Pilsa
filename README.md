# 필사 (Pilsa) — 1단계 MVP

책을 사진으로 찍어 올리고, 화면을 나눠 보면서 옮겨 쓰는(필사) 앱.
웹 · iOS · Android를 하나의 Flutter 코드베이스로 지원합니다.

> 앱 이름은 임시(pilsa)이며 출시 전에 확정 예정.

## 1단계 MVP 기능

- 책 사진 촬영/가져오기(노트당 여러 장), 사진 없이 시작도 가능
- 방향 반응형 분할 화면: 세로=상하, 가로=좌우 (구분선 드래그로 비율 조절, 노트별 저장)
- 사진 뷰어: 핀치 줌 / 팬 / 페이지 넘김(여러 장)
- 필사 에디터(flutter_quill): 굵게·기울임·밑줄·취소선·글자색·배경색·헤더·목록·정렬 등 기본 꾸미기
- 자동 저장(입력 멈춤 0.7초 후), 저장 상태 표시
- 라이브러리: 목록형 / 갤러리형(필사 글 미리보기 카드) 전환, 폴더(중첩 가능)
- 노트/폴더 이름 변경·삭제 (노트는 소프트 삭제 — 추후 동기화 대비)
- 라이트 / 다크 / 시스템 테마 (설정에 영속화)
- 로컬 우선 저장: Drift(SQLite). 웹은 IndexedDB 영속화

## 기술 스택

| 영역 | 선택 |
|---|---|
| 프레임워크 | Flutter (Material 3), 한글 폰트 Noto Sans KR 내장 |
| 상태 관리 | Riverpod |
| 라우팅 | go_router |
| 로컬 DB | Drift(SQLite) — 모바일: NativeDatabase, 웹: sql.js + IndexedDB |
| 에디터 | flutter_quill (Delta JSON 저장) |
| 사진 | image_picker |

## 실행 방법

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # drift 코드 생성(변경 시)

# 웹
flutter run -d chrome
flutter build web --no-web-resources-cdn   # 오프라인/사내망 대응 빌드

# 모바일 (사용자 컴퓨터에서)
flutter run -d <device>
flutter build apk        # Android
flutter build ipa        # iOS (macOS + Xcode 필요)
```

## 테스트

```bash
flutter analyze
flutter test                       # 단위(리포지토리/DB) + 위젯 테스트
```

E2E(웹) 검증은 Playwright 스크립트로 수행했습니다:
빈 화면 → 폴더 생성 → 사진 2장으로 필사 생성 → 본문 입력/굵게 →
제목 입력 → 가로/세로 분할 → 목록/갤러리 → 다크 테마 → 새로고침 영속성
(12/12 통과).

## 프로젝트 구조

```
lib/
├── app/          # 앱 셸: 테마, 라우터, 전역 프로바이더
├── core/widgets/ # SplitView(방향 반응형 분할 화면)
├── data/
│   ├── db/       # Drift 테이블·연결(플랫폼별 conditional import)
│   └── repositories/
└── features/
    ├── library/  # 홈: 목록/갤러리, 폴더
    ├── note/     # 필사 화면: 뷰어 + 에디터
    └── settings/ # 테마 설정
```

핵심 설계:

- **뷰어 추상화**: 사진 뷰어는 `ImagePagesViewer`. 2단계 PDF, 4단계 EPUB을
  같은 자리에 끼워 넣도록 노트 `kind` 필드와 화면 구조를 분리해 둠.
- **동기화 대비 스키마**: 모든 ID는 UUID, `updatedAt`/`deletedAt`(소프트 삭제)
  포함 → 3단계 Supabase 동기화 시 스키마 변경 불필요.
- **이미지 저장**: MVP는 모든 플랫폼 공통으로 DB BLOB에 저장(단순·이식성).
  용량 최적화가 필요해지면 파일 저장소로 이전.

## 알려진 제한 / 다음 단계

- **웹 DB 드라이버**: 이 빌드 환경에서 GitHub 릴리스 자산을 받을 수 없어
  웹은 sql.js(레거시 drift web) 기반. 정식 권장 방식으로 바꾸려면
  [sqlite3.dart 릴리스](https://github.com/simolus3/sqlite3.dart/releases)의
  `sqlite3.wasm`과 [drift 릴리스](https://github.com/simolus3/drift/releases)의
  `drift_worker.js`를 `web/`에 넣고 `lib/data/db/connection/web.dart`를
  `WasmDatabase.open(...)`으로 교체하면 됩니다(데이터 마이그레이션은 drift 문서 참고).
- 2단계: PDF 뷰어(pdfrx), 손글씨(펜) 입력, 노트 폴더 이동 UI
- 3단계: Supabase 계정 + 클라우드 동기화
- 4단계: EPUB 뷰어

## GitHub에 올리기

```bash
# GitHub에서 빈 저장소(pilsa)를 만든 뒤:
git remote add origin https://github.com/<계정>/pilsa.git
git push -u origin main
```
