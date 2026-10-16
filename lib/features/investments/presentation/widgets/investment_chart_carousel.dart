import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../domain/investment_math.dart';
import 'investment_allocation_chart.dart';
import 'investment_chart_section.dart';

/// The portfolio charts as swipeable slides: value over time, then allocation
/// by asset type.
///
/// Falls back to the value chart alone when nothing held has a value to slice.
class InvestmentChartCarousel extends StatefulWidget {
  final InvestmentSummary summary;

  const InvestmentChartCarousel({super.key, required this.summary});

  @override
  State<InvestmentChartCarousel> createState() =>
      _InvestmentChartCarouselState();
}

class _InvestmentChartCarouselState extends State<InvestmentChartCarousel> {
  // Only used for the single frame before the first slide has been measured.
  static const _fallbackHeight = 320.0;

  final _controller = PageController();
  final _heights = <int, double>{};
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHeight(int index, double height) {
    if (!mounted || _heights[index] == height) return;
    setState(() => _heights[index] = height);
  }

  @override
  Widget build(BuildContext context) {
    final allocation = buildInvestmentAllocation(widget.summary.assets);
    final valueChart = InvestmentChartSection(summary: widget.summary);
    if (allocation.isEmpty) return valueChart;

    final pages = <Widget>[
      valueChart,
      InvestmentAllocationChart(slices: allocation),
    ];

    final isLight = AppThemeProvider.isLightMode(context);
    final activeDot =
        isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold;
    final idleDot = isLight
        ? Colors.black.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.25);

    return Column(
      children: [
        // A PageView needs a fixed height but the slides differ, so it follows
        // the measured height of whichever slide is showing.
        AnimatedContainer(
          duration: _heights.containsKey(_page)
              ? const Duration(milliseconds: 200)
              : Duration.zero,
          curve: Curves.easeOut,
          height: _heights[_page] ?? _fallbackHeight,
          child: PageView.builder(
            controller: _controller,
            // Unclipped so card shadows are not cut off at the slide's edge.
            clipBehavior: Clip.none,
            itemCount: pages.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (_, index) => OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: _MeasureHeight(
                onChange: (height) => _onHeight(index, height),
                child: pages[index],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? activeDot : idleDot,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Reports its child's laid-out height whenever it changes.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onChange;

  const _MeasureHeight({required this.onChange, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  ValueChanged<double> onChange;
  double? _reported;

  _RenderMeasureHeight(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    // setState is not allowed during layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(height));
  }
}
