import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('테마'),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('시스템 설정 따르기'),
            value: ThemeMode.system,
            groupValue: mode,
            onChanged: (m) => ref.read(themeModeProvider.notifier).set(m!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('라이트'),
            value: ThemeMode.light,
            groupValue: mode,
            onChanged: (m) => ref.read(themeModeProvider.notifier).set(m!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('다크'),
            value: ThemeMode.dark,
            groupValue: mode,
            onChanged: (m) => ref.read(themeModeProvider.notifier).set(m!),
          ),
          const Divider(),
          const ListTile(
            title: Text('필사 (Pilsa)'),
            subtitle: Text('1단계 MVP — 이름은 출시 전에 정할 예정'),
          ),
        ],
      ),
    );
  }
}
