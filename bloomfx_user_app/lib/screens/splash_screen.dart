import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bgFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoPulse;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;
  late Animation<double> _poweredFade;
  late Animation<double> _poweredGlow;
  late Animation<double> _buttonFade;
  late Animation<Offset> _buttonSlide;

  String _typewriterText = '';
  int _typewriterIndex = 0;
  Timer? _typewriterTimer;
  final String _typewriterTarget = 'Copy Experienced Traders';
  bool _showButton = false;

  final List<_Particle> _particles = [];
  final List<_LightStreak> _streaks = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 1.0 + _random.nextDouble() * 3.0,
        speedX: (_random.nextDouble() - 0.5) * 0.002,
        speedY: (_random.nextDouble() - 0.5) * 0.002,
        opacity: 0.2 + _random.nextDouble() * 0.6,
      ));
    }

    for (int i = 0; i < 5; i++) {
      _streaks.add(_LightStreak(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        width: 50 + _random.nextDouble() * 150,
        height: 1.0 + _random.nextDouble() * 2.0,
        speed: 0.001 + _random.nextDouble() * 0.003,
        opacity: 0.05 + _random.nextDouble() * 0.1,
      ));
    }

    _controller = AnimationController(
      duration: const Duration(seconds: 9),
      vsync: this,
    );

    _bgFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.2, curve: Curves.elasticOut)),
    );

    _logoPulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.8, 2.0, curve: Curves.easeInOutSine)),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(1.2, 2.0, curve: Curves.easeOutCubic)),
    );

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(1.2, 2.0, curve: Curves.easeIn)),
    );

    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(2.5, 3.5, curve: Curves.easeIn)),
    );

    _poweredFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(3.5, 4.5, curve: Curves.easeIn)),
    );

    _poweredGlow = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(3.5, 5.5, curve: Curves.easeInOutSine)),
    );

    _buttonFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(5.5, 6.5, curve: Curves.easeIn)),
    );

    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(5.5, 6.5, curve: Curves.easeOutCubic)),
    );

    _controller.addListener(() {
      for (final p in _particles) {
        p.x += p.speedX;
        p.y += p.speedY;
        if (p.x < 0 || p.x > 1) p.speedX *= -1;
        if (p.y < 0 || p.y > 1) p.speedY *= -1;
      }
      for (final s in _streaks) {
        s.x += s.speed;
        if (s.x > 1.2) s.x = -0.2;
      }
      setState(() {});
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showButton = true);
      }
    });

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), _startTypewriter);
  }

  void _startTypewriter() {
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_typewriterIndex < _typewriterTarget.length) {
        setState(() {
          _typewriterText += _typewriterTarget[_typewriterIndex];
          _typewriterIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _onGetStarted() {
    _typewriterTimer?.cancel();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      context.go('/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              // Background
              Container(
                color: Color.lerp(
                  const Color(0xFF0A0E1A),
                  const Color(0xFF0D1117),
                  _bgFade.value,
                ),
              ),

              // Particles
              CustomPaint(
                size: Size.infinite,
                painter: _ParticlePainter(_particles, _bgFade.value),
              ),

              // Light streaks
              if (_controller.value > 3.5)
                CustomPaint(
                  size: Size.infinite,
                  painter: _StreakPainter(_streaks, (_controller.value - 3.5) / 5.5),
                ),

              // Center content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Opacity(
                      opacity: _logoScale.value > 0 ? 1 : 0,
                      child: Transform.scale(
                        scale: _logoPulse.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFDAA520),
                                Color(0xFFB8860B),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.3 * _logoScale.value),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.trending_up_rounded,
                              size: 60,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Title
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: const Text(
                          'CP Bloom FX',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                color: Color(0xFFFFD700),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Typewriter subtitle
                    Opacity(
                      opacity: _subtitleFade.value,
                      child: Text(
                        _typewriterText,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFFB0B0B0),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Powered by
                    FadeTransition(
                      opacity: _poweredFade,
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            const Color(0xFFFFD700).withValues(alpha: _poweredGlow.value),
                            const Color(0xFFFFD700),
                            const Color(0xFFFFD700).withValues(alpha: _poweredGlow.value),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'Powered by AI Auto Trade System',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Get Started button
              if (_showButton)
                Positioned(
                  left: 40,
                  right: 40,
                  bottom: 80,
                  child: SlideTransition(
                    position: _buttonSlide,
                    child: FadeTransition(
                      opacity: _buttonFade,
                      child: GestureDetector(
                        onTap: _onGetStarted,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFDAA520),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  double x, y, size, speedX, speedY, opacity;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
  });
}

class _LightStreak {
  double x, y, width, height, speed, opacity;
  _LightStreak({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double fade;

  _ParticlePainter(this.particles, this.fade);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.0);
    for (final p in particles) {
      paint.color = const Color(0xFFFFD700).withValues(alpha: p.opacity * fade);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _StreakPainter extends CustomPainter {
  final List<_LightStreak> streaks;
  final double fade;

  _StreakPainter(this.streaks, this.fade);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in streaks) {
      final paint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: s.opacity * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(
        Offset(s.x * size.width, s.y * size.height),
        Offset(s.x * size.width + s.width, s.y * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StreakPainter oldDelegate) => true;
}
