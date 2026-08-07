import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/models/tarot_card.dart';

/// Widget hiển thị hình ảnh lá bài Tarot thông minh:
/// - Nếu image_path bắt đầu bằng "assets/" -> dùng Image.asset
/// - Nếu là đường dẫn tệp trên thiết bị -> dùng Image.file
/// - Fallback về icon nếu lỗi
class TarotCardImage extends StatelessWidget {
  final TarotCardModel card;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const TarotCardImage({
    Key? key,
    required this.card,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imagePath = card.imagePath;
    Widget imageWidget;

    if (imagePath.startsWith('assets/')) {
      imageWidget = Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://') ||
        imagePath.startsWith('blob:')) {
      imageWidget = Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else if (!kIsWeb && imagePath.isNotEmpty && File(imagePath).existsSync()) {
      imageWidget = Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else {
      imageWidget = _buildFallback();
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }
    return imageWidget;
  }

  Widget _buildFallback() {
    return SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: Icon(Icons.auto_stories, color: Colors.amberAccent, size: 40),
      ),
    );
  }
}
