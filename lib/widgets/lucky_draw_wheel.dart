import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LuckyDrawWheel extends StatefulWidget {
  final List<String> members;
  final String winnerName;
  final VoidCallback onSpinComplete;
  final bool isSpinning;

  const LuckyDrawWheel({
    super.key,
    required this.members,
    required this.winnerName,
    required this.onSpinComplete,
    required this.isSpinning,
  });

  @override
  State<LuckyDrawWheel> createState() => _LuckyDrawWheelState();
}

class _LuckyDrawWheelState extends State<LuckyDrawWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _baseRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onSpinComplete();
      }
    });
  }

  @override
  void didUpdateWidget(covariant LuckyDrawWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Trigger spin when transition to isSpinning becomes true
    if (widget.isSpinning && !oldWidget.isSpinning) {
      _startSpin();
    }
  }

  void _startSpin() {
    if (widget.members.isEmpty) return;

    // Find the index of the winner
    final int winnerIndex = widget.members.indexOf(widget.winnerName);
    if (winnerIndex == -1) return;

    final int totalSectors = widget.members.length;
    final double sectorAngle = (2 * pi) / totalSectors;

    // Calculate target angle to align the winning sector at the top arrow (which is at -pi/2 or 270 degrees)
    // The sector center starts drawing from 0 degrees (right side). 
    // To align at 270 degrees, we calculate the required offset.
    final double winnerSectorCenter = (winnerIndex * sectorAngle) + (sectorAngle / 2);
    
    // Target rotation to align winner at the top (3*pi/2 or -pi/2)
    final double targetAlignment = (3 * pi / 2) - winnerSectorCenter;
    
    // We want the wheel to spin several full rotations (e.g. 6 full turns) plus the target offset.
    final double fullSpins = 6 * 2 * pi;
    final double endRotation = fullSpins + targetAlignment;

    _animation = Tween<double>(
      begin: _baseRotation % (2 * pi),
      end: endRotation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.fastLinearToSlowEaseIn,
    ));

    _controller.reset();
    _controller.forward();
    _baseRotation = endRotation;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer glowing neon ring decoration
            Container(
              width: 310,
              height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Colors.transparent,
                    Color(0x3310B981),
                    Color(0xFF14B8A6),
                  ],
                  stops: [0.75, 0.9, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentTeal.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            
            // The Spinning Painter Canvas
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animation.value,
                  child: CustomPaint(
                    size: const Size(280, 280),
                    painter: _WheelPainter(
                      members: widget.members,
                    ),
                  ),
                );
              },
            ),

            // Center Pin Indicator/Core Accent
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Colors.white, Color(0xFF0F172A)],
                  stops: [0.3, 1.0],
                ),
                border: Border.all(color: AppTheme.accentGold, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.star,
                color: AppTheme.accentGold,
                size: 20,
              ),
            ),

            // Top Arrow Indicator Pointer
            Positioned(
              top: 0,
              child: CustomPaint(
                size: const Size(30, 30),
                painter: _ArrowPointerPainter(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> members;

  _WheelPainter({required this.members});

  // Aesthetic curated colors for sections
  final List<Color> _colors = [
    const Color(0xFF0F766E), // Teal dark
    const Color(0xFF047857), // Green dark
    const Color(0xFFB45309), // Amber/Brown dark
    const Color(0xFF6B21A8), // Purple dark
    const Color(0xFFBE123C), // Rose dark
    const Color(0xFF1D4ED8), // Blue dark
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (members.isEmpty) return;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;
    final Rect rect = Rect.fromCircle(center: Offset(centerX, centerY), radius: radius);

    final int totalSectors = members.length;
    final double sweepAngle = (2 * pi) / totalSectors;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..color = AppTheme.borderDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < totalSectors; i++) {
      final double startAngle = i * sweepAngle;

      // Draw Sector Fill
      paint.color = _colors[i % _colors.length];
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      // Draw Sector Border separator lines
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);

      // Save canvas state to draw text inside sector
      canvas.save();

      // Relocate origin to wheel center
      canvas.translate(centerX, centerY);
      
      // Rotate to center of current sector
      canvas.rotate(startAngle + (sweepAngle / 2));

      // Draw member name text
      final textStyle = TextStyle(
        color: Colors.white.withOpacity(0.95),
        fontSize: totalSectors > 8 ? 10 : 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.6),
            offset: const Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      );

      final String name = members[i].split(" ").first; // Use first name to avoid overlap
      final textSpan = TextSpan(text: name, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      );

      textPainter.layout(maxWidth: radius - 35);
      
      // Draw text offset from the center along the radius
      textPainter.paint(
        canvas,
        Offset(radius - textPainter.width - 25, -textPainter.height / 2),
      );

      canvas.restore();
    }

    // Outer gold border ring
    final outerRingPaint = Paint()
      ..color = AppTheme.accentGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(Offset(centerX, centerY), radius, outerRingPaint);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.members != members;
  }
}

class _ArrowPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentGold
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height) // Point of arrow facing down
      ..lineTo(0, 0) // Left side of base
      ..lineTo(size.width, 0) // Right side of base
      ..close();

    // Draw shadow
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawPath(path, paint);

    // Add highlighted inner stroke
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
