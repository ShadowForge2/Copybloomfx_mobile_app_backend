import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    Future.delayed(const Duration(milliseconds: 3600), _navigateAway);
  }

  void _navigateAway() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      context.go('/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06080D),
      body: Stack(
        children: [
          // Background gradient glow
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD4AF37).withValues(alpha: 0.10),
                    const Color(0xFF9C7A28).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 800.ms)
                .then()
                .shimmer(duration: 2000.ms),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing aura
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.22),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 1000.ms)
                    .then()
                    .shimmer(duration: 2000.ms),

                // Rotating energy ring
                SizedBox(
                  width: 160,
                  height: 160,
                  child: AnimatedBuilder(
                    animation: _ringController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(160, 160),
                        painter: _RingPainter(
                          progress: _ringController.value,
                        ),
                        child: child,
                      );
                    },
                    child: const Center(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Center(
                          child: Text(
                            'CPB',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE8CE8C),
                              letterSpacing: 4,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFD4AF37),
                                  blurRadius: 30,
                                ),
                                Shadow(
                                  color: Colors.white,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate().scale(
                      begin: const Offset(0.3, 0.3),
                      end: const Offset(1, 1),
                      duration: 1200.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: 10),

                // Pulse aura on logo
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1.15, 1.15),
                      duration: 2000.ms,
                      curve: Curves.easeInOut,
                    )
                    .fadeIn(duration: 600.ms),

                const SizedBox(height: 10),

                Text(
                  'CPBloomFX',
                  style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFFE8CE8C),
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                )
                    .animate(delay: 600.ms)
                    .fadeIn(duration: 1000.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 10),

                Text(
                  'AI COPY TRADING SYSTEM',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF98A0B3),
                    fontSize: 12,
                    letterSpacing: 4,
                  ),
                )
                    .animate(delay: 1400.ms)
                    .fadeIn(duration: 1200.ms),
              ],
            ),
          ),

          // Bottom shimmer loading line
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 180,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFFD4AF37),
                      Color(0xFFE8CE8C),
                      Color(0xFFD4AF37),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 1600.ms),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer ring
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFD4AF37).withValues(alpha: 0.1),
          const Color(0xFFD4AF37),
          const Color(0xFFE8CE8C),
          const Color(0xFFD4AF37),
          const Color(0xFFD4AF37).withValues(alpha: 0.1),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 2 * pi,
      1.8 * pi,
      false,
      outerPaint,
    );

    // Inner ring (counter-rotating)
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF9C7A28).withValues(alpha: 0.05),
          const Color(0xFF9C7A28),
          const Color(0xFFD4AF37),
          const Color(0xFF9C7A28).withValues(alpha: 0.05),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 10));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      -progress * 2 * pi + pi / 4,
      2.0 * pi,
      false,
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
