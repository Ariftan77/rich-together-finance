import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Packs intact debt cards into left-to-right panels for a single image.
/// Measures real content height so wrapped notes never straddle a boundary.
class DebtSharePages extends MultiChildRenderObjectWidget {
  const DebtSharePages({super.key, required super.children});

  static const pageWidth = 380.0;
  static const pageHeight = 720.0;
  static const padding = 20.0;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDebtSharePages();
}

class _PageParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDebtSharePages extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _PageParentData();
    }
  }

  @override
  void performLayout() {
    const width = DebtSharePages.pageWidth;
    const padding = DebtSharePages.padding;
    const height = DebtSharePages.pageHeight;
    var page = 0;
    var y = padding;
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(
        const BoxConstraints.tightFor(width: width - padding * 2),
        parentUsesSize: true,
      );
      final data = child.parentData! as ContainerBoxParentData<RenderBox>;
      if (y > padding && y + child.size.height > height - padding) {
        tallest = tallest > y + padding ? tallest : y + padding;
        page++;
        y = padding;
      }
      data.offset = Offset(page * width + padding, y);
      y += child.size.height;
      child = data.nextSibling;
    }
    tallest = tallest > y + padding ? tallest : y + padding;
    // Oversized individual notes grow the canvas instead of losing content.
    size = Size(
      (page + 1) * width,
      page > 0 && tallest < height ? height : tallest,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
