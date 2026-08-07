import 'package:flutter/material.dart';

/// Widget TwinklingTitle hiển thị tiêu đề phát sáng lấp lánh phong cách huyền bí
class TwinklingTitle extends StatefulWidget {
  final String text;
  final double fontSize;
  final Color primaryColor;

  const TwinklingTitle({
    Key? key,
    required this.text,
    this.fontSize = 24.0,
    this.primaryColor = const Color(0xFFFFD700),
  }) : super(key: key);

  @override
  State<TwinklingTitle> createState() => _TwinklingTitleState();
}

class _TwinklingTitleState extends State<TwinklingTitle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            color: widget.primaryColor.withOpacity(_animation.value),
            shadows: [
              Shadow(
                blurRadius: 10.0 * _animation.value,
                color: widget.primaryColor.withOpacity(0.8),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        );
      },
    );
  }
}
