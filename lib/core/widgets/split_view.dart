import 'package:flutter/material.dart';

/// 기기 방향에 따라 자동으로 상하(세로) 또는 좌우(가로)로 나뉘는 분할 화면.
/// 가운데 구분선을 드래그하여 비율을 조절할 수 있다.
class SplitView extends StatelessWidget {
  const SplitView({
    super.key,
    required this.first,
    required this.second,
    required this.ratio,
    required this.onRatioChanged,
    this.minRatio = 0.15,
    this.maxRatio = 0.85,
    this.dividerThickness = 24,
  });

  /// 세로 화면에서 위, 가로 화면에서 왼쪽에 놓이는 위젯(콘텐츠 뷰어).
  final Widget first;

  /// 세로 화면에서 아래, 가로 화면에서 오른쪽에 놓이는 위젯(에디터).
  final Widget second;

  final double ratio;
  final ValueChanged<double> onRatioChanged;
  final double minRatio;
  final double maxRatio;
  final double dividerThickness;

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(builder: (context, orientation) {
      final vertical = orientation == Orientation.portrait;
      return LayoutBuilder(builder: (context, constraints) {
        final total = (vertical ? constraints.maxHeight : constraints.maxWidth) -
            dividerThickness;
        final clamped = ratio.clamp(minRatio, maxRatio);
        final firstExtent = (total * clamped).clamp(0.0, total);

        void onDrag(DragUpdateDetails d) {
          final delta = vertical ? d.delta.dy : d.delta.dx;
          final next = ((firstExtent + delta) / total).clamp(minRatio, maxRatio);
          onRatioChanged(next.toDouble());
        }

        final divider = MouseRegion(
          cursor: vertical
              ? SystemMouseCursors.resizeRow
              : SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: vertical ? onDrag : null,
            onHorizontalDragUpdate: vertical ? null : onDrag,
            child: SizedBox(
              width: vertical ? double.infinity : dividerThickness,
              height: vertical ? dividerThickness : double.infinity,
              child: Center(
                child: Container(
                  width: vertical ? 48 : 4,
                  height: vertical ? 4 : 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        );

        final children = [
          SizedBox(
            width: vertical ? null : firstExtent,
            height: vertical ? firstExtent : null,
            child: first,
          ),
          divider,
          Expanded(child: second),
        ];

        return vertical
            ? Column(children: children)
            : Row(children: children);
      });
    });
  }
}
