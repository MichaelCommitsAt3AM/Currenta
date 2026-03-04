// lib/features/news/presentation/widgets/heart_shower.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class HeartShower extends StatefulWidget {
  const HeartShower({
    super.key,
    required this.isAnimating,
    required this.color,
    this.onEnd,
  });

  final bool isAnimating;
  final Color color;
  final VoidCallback? onEnd;

  @override
  State<HeartShower> createState() => _HeartShowerState();
}

class _HeartShowerState extends State<HeartShower>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_HeartParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _particles.clear();
        if (widget.onEnd != null) widget.onEnd!();
      }
    });
  }

  @override
  void didUpdateWidget(HeartShower oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _spawnParticles();
      _controller.forward(from: 0);
    }
  }

  void _spawnParticles() {
    _particles.clear();
    for (int i = 0; i < 6; i++) {
      _particles.add(_HeartParticle(
        angle: -math.pi / 2 + (_random.nextDouble() - 0.5) * 0.8,
        speed: 100 + _random.nextDouble() * 100,
        size: 12 + _random.nextDouble() * 8,
        rotation: (_random.nextDouble() - 0.5) * 0.5,
      ));
    }
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
        if (!_controller.isAnimating && _particles.isEmpty) {
          return const SizedBox.shrink();
        }

        return CustomPaint(
          painter: _HeartShowerPainter(
            particles: _particles,
            progress: _controller.value,
            color: widget.color,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _HeartParticle {
  final double angle;
  final double speed;
  final double size;
  final double rotation;

  _HeartParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.rotation,
  });
}

class _HeartShowerPainter extends CustomPainter {
  final List<_HeartParticle> particles;
  final double progress;
  final Color color;

  _HeartShowerPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Heart Particles ────────────────────────────────────────
    final heartPaint = Paint()
      ..color = color.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0));

    // Origin (bottom left approx where the heart icon is)
    // Adjust based on NewsCard padding (24) and icon size (24)
    final Offset origin = Offset(36, size.height - 36);

    for (final p in particles) {
      final double distance = p.speed * progress;
      final double dx = math.cos(p.angle) * distance;
      final double dy = math.sin(p.angle) * distance;

      final Offset pos = origin + Offset(dx, dy);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rotation * progress);

      _drawHeart(canvas, p.size, heartPaint);
      canvas.restore();
    }
  }

  void _drawHeart(Canvas canvas, double size, Paint paint) {
    final path = Path();
    final width = size;
    final height = size;

    path.moveTo(0.5 * width, height * 0.35);
    path.cubicTo(0.2 * width, height * 0.1, -0.1 * width, height * 0.6,
        0.5 * width, height * 0.9);
    path.cubicTo(1.1 * width, height * 0.6, 0.8 * width, height * 0.1,
        0.5 * width, height * 0.35);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
