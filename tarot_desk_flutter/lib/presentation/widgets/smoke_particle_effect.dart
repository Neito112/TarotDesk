import 'dart:math';
import 'package:flutter/material.dart';

/// Widget SmokeParticleEffect vẽ các hạt khói phảng phất di chuyển ngẫu nhiên
class SmokeParticleEffect extends StatefulWidget {
  final Widget child;
  final bool enableSmoke;

  const SmokeParticleEffect({
    Key? key,
    required this.child,
    this.enableSmoke = true,
  }) : super(key: key);

  @override
  State<SmokeParticleEffect> createState() => _SmokeParticleEffectState();
}

class _SmokeParticleEffectState extends State<SmokeParticleEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    for (int i = 0; i < 25; i++) {
      _particles.add(_generateParticle());
    }
  }

  Particle _generateParticle() {
    return Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      radius: 15.0 + _random.nextDouble() * 35.0,
      opacity: 0.05 + _random.nextDouble() * 0.15,
      speedX: (_random.nextDouble() - 0.5) * 0.001,
      speedY: -0.0005 - _random.nextDouble() * 0.001,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableSmoke) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Cập nhật vị trí các hạt khói
        for (var p in _particles) {
          p.x += p.speedX;
          p.y += p.speedY;
          if (p.y < -0.1) {
            p.y = 1.1;
            p.x = _random.nextDouble();
          }
        }
        return CustomPaint(
          foregroundPainter: SmokePainter(_particles),
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

class Particle {
  double x;
  double y;
  double radius;
  double opacity;
  double speedX;
  double speedY;

  Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.speedX,
    required this.speedY,
  });
}

class SmokePainter extends CustomPainter {
  final List<Particle> particles;

  SmokePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0);

    for (var p in particles) {
      paint.color = Colors.white.withOpacity(p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
