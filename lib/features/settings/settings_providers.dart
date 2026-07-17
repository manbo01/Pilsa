import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// 라이트/다크/시스템 테마 모드. DB에 영속화된다.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final v = await ref.read(databaseProvider).getSetting('themeMode');
    if (v != null) {
      state = ThemeMode.values.firstWhere((m) => m.name == v,
          orElse: () => ThemeMode.system);
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(databaseProvider).setSetting('themeMode', mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// 라이브러리 보기 방식(목록형=false / 갤러리형=true). DB에 영속화된다.
class GalleryViewNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final v = await ref.read(databaseProvider).getSetting('galleryView');
    if (v != null) state = v == 'true';
  }

  Future<void> set(bool gallery) async {
    state = gallery;
    await ref.read(databaseProvider).setSetting('galleryView', '$gallery');
  }
}

final galleryViewProvider =
    NotifierProvider<GalleryViewNotifier, bool>(GalleryViewNotifier.new);
