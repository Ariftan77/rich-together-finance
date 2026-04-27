import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../dashboard/presentation/dashboard_shell.dart';

/// Full-screen Instagram Stories-style onboarding screen.
///
/// Displays 3 slides with full-bleed images, auto-advancing progress bars,
/// tap-to-navigate, and long-press-to-pause behaviour.
///
/// Each slide contains 3 frames (WebP images). Frames are derived from the
/// controller's animation value — no extra timer is needed. The progress bar
/// still represents the whole story duration so the UX is unchanged.
class OnboardingStoriesScreen extends ConsumerStatefulWidget {
  const OnboardingStoriesScreen({super.key});

  @override
  ConsumerState<OnboardingStoriesScreen> createState() =>
      _OnboardingStoriesScreenState();
}

class _OnboardingStoriesScreenState
    extends ConsumerState<OnboardingStoriesScreen>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Story / frame data
  // ---------------------------------------------------------------------------

  /// Returns the frame lists for the current language suffix.
  /// Index 0 = story 1, index 1 = story 2, index 2 = story 3.
  /// Each inner list has 3 frame paths.
  List<List<String>> _buildStoryFrames(String langSuffix) {
    return List.generate(3, (storyIndex) {
      final s = storyIndex + 1; // 1-based story number
      return List.generate(3, (frameIndex) {
        final f = frameIndex + 1; // 1-based frame number
        return 'assets/images/onboarding_${s}_${f}_$langSuffix.webp';
      });
    });
  }

  static const int _slideCount = 1;
  static const int _frameCount = 3;

  /// Total duration for one story (3 frames × 2 s each).
  static const Duration _slideDuration = Duration(seconds: 6);

  late AnimationController _controller;
  int _currentIndex = 0;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _slideDuration)
      ..addStatusListener(_onAnimationStatus)
      ..forward();
    AnalyticsService.trackScreenView('Onboarding_Stories');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Animation callbacks
  // ---------------------------------------------------------------------------

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _advanceSlide();
    }
  }

  void _advanceSlide() {
    if (_currentIndex < _slideCount - 1) {
      AnalyticsService.trackOnboardingStepCompleted('stories_slide_${_currentIndex + 1}');
      setState(() => _currentIndex++);
      _controller
        ..reset()
        ..forward();
    } else {
      // Last slide auto-advanced or tapped through — fire its completion
      AnalyticsService.trackOnboardingStepCompleted('stories_slide_${_currentIndex + 1}');
      _navigateToDashboard(skipped: false);
    }
  }

  void _goToPreviousSlide() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
    _controller
      ..reset()
      ..forward();
  }

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  void _onTapUp(TapUpDetails details) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isRightHalf = details.globalPosition.dx > screenWidth / 2;

    if (isRightHalf) {
      _advanceSlide();
    } else {
      _goToPreviousSlide();
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _controller.stop();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _controller.forward();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _navigateToDashboard({bool skipped = false}) {
    if (!mounted) return;
    if (skipped) {
      // Fire the current slide as skipped so we know where user dropped off
      AnalyticsService.trackOnboardingStepCompleted(
        'stories_slide_${_currentIndex + 1}',
        skipped: true,
      );
    }
    AnalyticsService.trackOnboardingCompleted();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardShell()),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final langSuffix = locale.languageCode == 'id' ? 'id' : 'en';
    final storyFrames = _buildStoryFrames(langSuffix);
    final currentFrames = storyFrames[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTapUp,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed background image — animated frame switcher
            _SlideImage(
              frames: currentFrames,
              controller: _controller,
              frameCount: _frameCount,
            ),

            // Top scrim for progress bar readability
            _TopScrim(),

            // Bottom scrim for button readability
            _BottomScrim(),

            // Progress bars — pinned to top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: _ProgressBars(
                    slideCount: _slideCount,
                    currentIndex: _currentIndex,
                    controller: _controller,
                  ),
                ),
              ),
            ),

            // Bottom action buttons — pinned to bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _BottomActions(
                    currentIndex: _currentIndex,
                    onSkip: () => _navigateToDashboard(skipped: true),
                    onGetStarted: () => _navigateToDashboard(skipped: false),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Slide image — multi-frame with crossfade
// =============================================================================

/// Renders the current story frame derived from [controller]'s value.
/// Frames are equally distributed across the 0→1 animation range.
/// [AnimatedSwitcher] with a [FadeTransition] crossfades between frames.
class _SlideImage extends StatefulWidget {
  final List<String> frames;
  final AnimationController controller;
  final int frameCount;

  const _SlideImage({
    required this.frames,
    required this.controller,
    required this.frameCount,
  });

  @override
  State<_SlideImage> createState() => _SlideImageState();
}

class _SlideImageState extends State<_SlideImage> {
  late int _frameIndex;

  @override
  void initState() {
    super.initState();
    _frameIndex = 0;
    widget.controller.addListener(_onControllerValue);
  }

  @override
  void didUpdateWidget(_SlideImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerValue);
      widget.controller.addListener(_onControllerValue);
    }
    // Reset frame when the story (and therefore frames list) changes.
    if (oldWidget.frames != widget.frames) {
      _frameIndex = 0;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerValue);
    super.dispose();
  }

  void _onControllerValue() {
    final derived = (widget.controller.value * widget.frameCount)
        .floor()
        .clamp(0, widget.frameCount - 1);
    if (derived != _frameIndex) {
      setState(() => _frameIndex = derived);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.frames[_frameIndex];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: SizedBox.expand(
        key: ValueKey<String>(path),
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

// =============================================================================
// Scrim overlays
// =============================================================================

class _TopScrim extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 160,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.black.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 200,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.black.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Progress bars
// =============================================================================

class _ProgressBars extends StatelessWidget {
  final int slideCount;
  final int currentIndex;
  final AnimationController controller;

  const _ProgressBars({
    required this.slideCount,
    required this.currentIndex,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(slideCount, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < slideCount - 1 ? 4 : 0),
            child: _SingleProgressBar(
              state: index < currentIndex
                  ? _BarState.completed
                  : index == currentIndex
                      ? _BarState.active
                      : _BarState.upcoming,
              controller: controller,
            ),
          ),
        );
      }),
    );
  }
}

enum _BarState { completed, active, upcoming }

class _SingleProgressBar extends StatelessWidget {
  final _BarState state;
  final AnimationController controller;

  const _SingleProgressBar({
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1.5),
        child: state == _BarState.active
            ? AnimatedBuilder(
                animation: controller,
                builder: (context, _) => LinearProgressIndicator(
                  value: controller.value,
                  backgroundColor: Colors.white.withValues(alpha: 0.30),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : LinearProgressIndicator(
                value: state == _BarState.completed ? 1.0 : 0.0,
                backgroundColor: Colors.white.withValues(alpha: 0.30),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
      ),
    );
  }
}

// =============================================================================
// Bottom actions
// =============================================================================

class _BottomActions extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onSkip;
  final VoidCallback onGetStarted;

  const _BottomActions({
    required this.currentIndex,
    required this.onSkip,
    required this.onGetStarted,
  });

  bool get _isLastSlide => currentIndex == 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Skip button — visible on slides 0 and 1 only
        if (!_isLastSlide)
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              ),
            ),
            child: const Text(
              'Skip',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          )
        else
          const SizedBox.shrink(),

        // Get Started button — visible on slide 2 only
        if (_isLastSlide)
          GlassButton(
            text: 'Track your first expense  →',
            size: GlassButtonSize.medium,
            onPressed: onGetStarted,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
