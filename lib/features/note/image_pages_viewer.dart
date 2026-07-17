import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 책 사진 뷰어: 여러 장을 좌우로 넘기고, 각 장은 핀치 줌/팬(자체 스크롤)이 된다.
class ImagePagesViewer extends StatefulWidget {
  const ImagePagesViewer({
    super.key,
    required this.images,
    this.onAddImages,
  });

  final List<Uint8List> images;
  final VoidCallback? onAddImages;

  @override
  State<ImagePagesViewer> createState() => _ImagePagesViewerState();
}

class _ImagePagesViewerState extends State<ImagePagesViewer> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.images.isEmpty) {
      return Container(
        color: scheme.surfaceContainerLowest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, size: 48, color: scheme.outline),
              const SizedBox(height: 8),
              Text('책 사진이 없어요', style: TextStyle(color: scheme.outline)),
              if (widget.onAddImages != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: widget.onAddImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('사진 추가'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      color: scheme.surfaceContainerLowest,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 0.8,
              maxScale: 8,
              child: Center(
                child: Image.memory(
                  widget.images[i],
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_page + 1} / ${widget.images.length}',
                      style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
            ),
          if (widget.onAddImages != null)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: '사진 추가',
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                onPressed: widget.onAddImages,
              ),
            ),
        ],
      ),
    );
  }
}
