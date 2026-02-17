
import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../auth/presentation/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Simulate loading or wait for initialization
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // #0F172A 0%
              Color(0xFF171E2E), // #171E2E 30%
              Color(0xFF854D0E), // #854D0E 80%
              Color(0xFFC25400), // #C25400 100%
            ],
            stops: [0.0, 0.3, 0.8, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Center Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with glow
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGold.withValues(alpha: 0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/splash_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Title
                  Text(
                    'RICH TOGETHER',
                    style: AppTypography.textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4, // tracking-[0.15em] approx
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Subtitle
                  Text(
                    'EST. MMXXVI',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6.0, // tracking-[0.6em]
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Loading Dots
            Positioned(
              bottom: 64, // bottom-16 in web (approx 64px or so, maybe 4rem=64px)
              left: 0,
              right: 0,
              child: const Center(
                child: _LoadingDots(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final opacity = _getOpacity(index, _controller.value);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  double _getOpacity(int index, double progress) {
    // Simple staggered opacity
    // 0: 0.3 -> 1.0 -> 0.3
    // 1: 0.3 -> 1.0 -> 0.3 (delayed)
    // 2: 0.3 -> 1.0 -> 0.3 (delayed more)
    
    // Adjusted logic:
    // Wave effect
    double start = index * 0.2;
    double end = start + 0.4;
    
    if (progress >= start && progress <= end) {
      // increasing
      return 0.3 + 0.7 * ((progress - start) / 0.4);
    } else if (progress > end && progress <= end + 0.4) {
      // decreasing
      return 1.0 - 0.7 * ((progress - end) / 0.4);
    } else {
      return 0.3;
    }
  }
}
