import 'package:go_router/go_router.dart';

import '../features/library/library_screen.dart';
import '../features/note/note_screen.dart';
import '../features/settings/settings_screen.dart';

GoRouter buildRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              LibraryScreen(folderId: state.uri.queryParameters['folder']),
        ),
        GoRoute(
          path: '/note/:id',
          builder: (context, state) =>
              NoteScreen(noteId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
