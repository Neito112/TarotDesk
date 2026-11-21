import 'dart:math';
import 'package:flutter/material.dart';

/// Hiệu ứng sương khói CHÂN THẬT: các cụm khói có VÒNG ĐỜI —
/// sinh ra nhỏ và đậm ở dưới, bay lên, nở to dần, uốn lượn theo
/// gió, rồi loãng dần và tan biến ở trên — như khói trầm thật.
///
/// Khác bản cũ (hình tròn mờ đều, bay thẳng tốc độ cố định, độ mờ
/// không đổi, hết là "dịch chuyển tức thời" về đáy):
///  - Mỗi cụm khói có tuổi: độ mờ vào nhanh rồi tan dần (fade-in
///    12% đầu đời, fade-out tuyến tính tới cuối đời), bán kính NỞ
///    TO theo tuổi (khói thật nở ra khi bay lên và loãng đi).
///  - Uốn lượn: vị trí ngang dao động hình sin theo tuổi, biên độ
///    càng lớn khi khói càng lên cao (khói bay lên thì dạt theo gió).
///  - Vẽ bằng gradient xuyên tâm (đậm ở giữa, mờ dần ra mép) thay
///    cho MaskFilter.blur trên hình tròn (vừa mềm/wispy hơn, vừa
///    nhẹ hơn cho GPU — không còn blur filter đắt).
///  - Màu khói hơi xanh-oải hương nhạt (không trắng tinh) cho hợp
///    không khí huyền bí, độ mờ thấp để không che nội dung.
///  - Bán kính theo TỈ LỆ của hộp chứa (size.shortestSide) nên
///    dùng được cả cho khói toàn màn hình lẫn khói nhỏ trên cây
///    trầm — không bị quá to trong hộp nhỏ.
///
/// API giữ nguyên (child + enableSmoke) nên mọi màn hình đang dùng
/// (home, history, select_deck, reading) không phải sửa gì.
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

class _SmokeParticleEffectState extends State<SmokeParticleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_SmokePuff> _puffs = [];
  final Random _random = Random();
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Controller chỉ làm "đồng hồ" (ticker) — mỗi khung hình cập
    // nhật tuổi của các cụm khói bằng thời gian thực (dt).
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_tick);
    // 32 cụm khói, tuổi ban đầu ngẫu nhiên để khói đã "đang bay"
    // ngay từ khung hình đầu (không phải chờ sinh từ đáy).
    for (int i = 0; i < 32; i++) {
      _puffs.add(_newPuff(initialAge: _random.nextDouble()));
    }
  }

  _SmokePuff _newPuff({double initialAge = 0}) {
    return _SmokePuff(
      birthX: _random.nextDouble(),
      age: initialAge,
      // Vòng đời 7–14 giây: khói bay chậm, thong thả như trầm.
      lifetime: 7 + _random.nextDouble() * 7,
      // Bán kính theo tỉ lệ hộp chứa: sinh nhỏ (1.2–3.2%),
      // nở to gấp ~2.5 lần khi tan (4–8%) — đủ nhỏ để là dải
      // khói mảnh, không thành đám mây tròn lớn.
      startRadiusFrac: 0.012 + _random.nextDouble() * 0.02,
      endRadiusFrac: 0.04 + _random.nextDouble() * 0.04,
      maxOpacity: 0.05 + _random.nextDouble() * 0.10,
      // Uốn lượn ngang: biên độ 1–4% chiều rộng, tần số 0.5–1.5
      // vòng trong một đời khói, pha ngẫu nhiên.
      swayAmpFrac: 0.01 + _random.nextDouble() * 0.03,
      swayFreq: 0.5 + _random.nextDouble() * 1.0,
      phase: _random.nextDouble() * 2 * pi,
    );
  }

  void _tick() {
    final now = DateTime.now();
    final dt = now.difference(_lastTick).inMilliseconds / 1000.0;
    _lastTick = now;
    // Bỏ qua tick đầu / tab bị ẩn lâu (dt quá lớn = nhảy cóc).
    if (dt <= 0 || dt > 0.5) return;
    setState(() {
      for (int i = 0; i < _puffs.length; i++) {
        final p = _puffs[i];
        p.age += dt / p.lifetime;
        if (p.age >= 1) _puffs[i] = _newPuff();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableSmoke) {
      return widget.child;
    }
    return CustomPaint(
      foregroundPainter: _SmokePainter(_puffs),
      child: widget.child,
    );
  }
}

/// Một cụm khói: sinh ở dưới (y ~1.05), bay lên và tan ở trên
/// (y ~-0.15) trong một vòng đời. Mọi vị trí/kích thước đều theo
/// tỉ lệ của hộp chứa nên khói tự co giãn theo màn hình.
class _SmokePuff {
  double birthX; // 0..1 (vị trí ngang lúc sinh)
  double age; // 0..1 (phần vòng đời đã qua)
  double lifetime; // giây
  double startRadiusFrac;
  double endRadiusFrac;
  double maxOpacity;
  double swayAmpFrac;
  double swayFreq;
  double phase;

  _SmokePuff({
    required this.birthX,
    required this.age,
    required this.lifetime,
    required this.startRadiusFrac,
    required this.endRadiusFrac,
    required this.maxOpacity,
    required this.swayAmpFrac,
    required this.swayFreq,
    required this.phase,
  });

  // Vị trí dọc: bay lên đều theo tuổi (1.05 -> -0.15).
  double get y => 1.05 - age * 1.2;

  // Vị trí ngang: sinh ở birthX, uốn lượn hình sin; biên độ càng
  // lớn khi khói càng lên cao (0.5x lúc sinh -> 1.5x lúc tan).
  double get x =>
      birthX +
      swayAmpFrac * (0.5 + age) * sin(phase + age * swayFreq * 2 * pi);

  // Bán kính nở to theo tuổi (khói nở ra khi bay lên).
  double radiusFrac() =>
      startRadiusFrac + (endRadiusFrac - startRadiusFrac) * age;

  // Độ mờ: vào nhanh (12% đầu đời) rồi tan dần tới cuối đời.
  double opacity() {
    final fadeIn = (age / 0.12).clamp(0.0, 1.0);
    final fadeOut = (1 - age).clamp(0.0, 1.0);
    return maxOpacity * fadeIn * fadeOut;
  }
}

class _SmokePainter extends CustomPainter {
  final List<_SmokePuff> puffs;

  _SmokePainter(this.puffs);

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.shortestSide;
    for (final p in puffs) {
      final opacity = p.opacity();
      if (opacity <= 0.001) continue;
      final radius = p.radiusFrac() * base;
      final center = Offset(p.x * size.width, p.y * size.height);
      // Cụm khói chính: dải DỌC (cao gấp ~1.8 lần rộng) — sợi khói
      // bay lên trông như dải mỏng uốn lượn, không phải đĩa tròn.
      _drawWisp(canvas, center, radius, opacity, 1.8);
      // Vệ tinh nhỏ lệch sang một bên để cụm khói không tròn đều.
      _drawWisp(
        canvas,
        Offset(center.dx + radius * 0.45, center.dy - radius * 0.35),
        radius * 0.55,
        opacity * 0.7,
        1.6,
      );
    }
  }

  /// Vẽ một dải khói: gradient xuyên tâm (đậm ở giữa, mờ dần ra
  /// mép) rồi kéo dài theo chiều dọc thành sợi mỏng. Shader được
  /// tạo SAU khi translate/scale nên gradient căng theo đúng hình
  /// oval (không bị lệch tâm).
  void _drawWisp(
      Canvas canvas, Offset center, double radius, double opacity, double stretchY) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, stretchY);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromRGBO(228, 232, 248, opacity),
          Color.fromRGBO(228, 232, 248, opacity * 0.45),
          Color.fromRGBO(228, 232, 248, 0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawCircle(Offset.zero, radius, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
