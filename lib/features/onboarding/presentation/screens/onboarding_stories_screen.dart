import 'package:flutter/material.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../dashboard/presentation/dashboard_shell.dart';

/// Full-screen Instagram Stories-style onboarding screen.
///
/// Displays 3 slides with full-bleed images, auto-advancing progress bars,
/// tap-to-navigate, and long-press-to-pause behaviour.
class OnboardingStoriesScreen extends StatefulWidget {
  const OnboardingStoriesScreen({super.key});

  @override
  State<OnboardingStoriesScreen> createState() => _OnboardingStoriesScreenState();
}

class _OnboardingStoriesScreenState extends State<OnboardingStoriesScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _images = [
    'assets/images/onboarding_1.png',
    'assets/images/onboarding_2.png',
    'assets/images/onboarding_3.png',
  ];

  static const int _slideCount = 3;
  static const Duration _slideDuration = Duration(seconds: 4);

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
      setState(() => _currentIndex++);
      _controller
        ..reset()
        ..forward();
    } else {
      _navigateToDashboard();
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

  void _navigateToDashboard() {
    if (!mounted) return;
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
            // Full-bleed background image
            _SlideImage(imagePath: _images[_currentIndex]),

            // Top scrim for progress bars readability
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
                    onSkip: _navigateToDashboard,
                    onGetStarted: _navigateToDashboard,
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
// Slide image
// =============================================================================

class _SlideImage extends StatelessWidget {
  final String imagePath;

  const _SlideImage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
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

  bool get _isLastSlide => currentIndex == 2;

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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
            child: const Text(
              'Skip',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          )
        else
          const SizedBox.shrink(),

        // Get Started button — visible on slide 2 only
        if (_isLastSlide)
          GlassButton(
            text: 'Get Started  →',
            size: GlassButtonSize.medium,
            onPressed: onGetStarted,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
