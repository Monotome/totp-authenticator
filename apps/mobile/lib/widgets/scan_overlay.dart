import 'package:flutter/material.dart';
import '../theme.dart';

/// Overlay widget drawn on top of the camera preview.
/// Features a transparent cutout reticle, glowing corner brackets,
/// an animated laser sweep line, and user guide text.
class ScanOverlay extends StatefulWidget {
  final double scanWindowSize;

  const ScanOverlay({
    super.key,
    this.scanWindowSize = 260.0,
  });

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final windowSize = widget.scanWindowSize;
    final left = (screenSize.width - windowSize) / 2;
    final top = (screenSize.height - windowSize) / 2 - 40; // slightly above center
    final scanRect = Rect.fromLTWH(left, top, windowSize, windowSize);

    return Stack(
      children: [
        // Darkened background with cutout
        CustomPaint(
          size: screenSize,
          painter: _CutoutOverlayPainter(
            scanRect: scanRect,
            overlayColor: Colors.black.withValues(alpha: 0.65),
            borderColor: AppTheme.accentCyan,
            borderRadius: 20.0,
          ),
        ),

        // Animated laser beam inside cutout
        Positioned(
          left: scanRect.left + 8,
          top: scanRect.top + 8,
          width: scanRect.width - 16,
          height: scanRect.height - 16,
          child: AnimatedBuilder(
            animation: _laserAnimation,
            builder: (context, _) {
              final laserTop = _laserAnimation.value * (scanRect.height - 24);
              return Stack(
                children: [
                  Positioned(
                    top: laserTop,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentCyan.withValues(alpha: 0.0),
                            AppTheme.accentCyan,
                            AppTheme.accentCyan.withValues(alpha: 0.0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentCyan.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Helper instruction text under the cutout
        Positioned(
          top: scanRect.bottom + 28,
          left: 24,
          right: 24,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: const Text(
                'Căn chỉnh mã QR vào giữa khung ngắm',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CutoutOverlayPainter extends CustomPainter {
  final Rect scanRect;
  final Color overlayColor;
  final Color borderColor;
  final double borderRadius;

  _CutoutOverlayPainter({
    required this.scanRect,
    required this.overlayColor,
    required this.borderColor,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final rrect = RRect.fromRectAndRadius(
      scanRect,
      Radius.circular(borderRadius),
    );

    final cutoutPath = Path()..addRRect(rrect);

    // Subtract cutout from full screen
    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final bgPaint = Paint()..color = overlayColor;
    canvas.drawPath(combinedPath, bgPaint);

    // Draw reticle corner brackets
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;

    // Top-Left corner
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.top + cornerLength)
        ..lineTo(scanRect.left, scanRect.top + borderRadius)
        ..arcToPoint(
          Offset(scanRect.left + borderRadius, scanRect.top),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(scanRect.left + cornerLength, scanRect.top),
      cornerPaint,
    );

    // Top-Right corner
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cornerLength, scanRect.top)
        ..lineTo(scanRect.right - borderRadius, scanRect.top)
        ..arcToPoint(
          Offset(scanRect.right, scanRect.top + borderRadius),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(scanRect.right, scanRect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-Left corner
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.bottom - cornerLength)
        ..lineTo(scanRect.left, scanRect.bottom - borderRadius)
        ..arcToPoint(
          Offset(scanRect.left + borderRadius, scanRect.bottom),
          radius: Radius.circular(borderRadius),
          clockwise: false,
        )
        ..lineTo(scanRect.left + cornerLength, scanRect.bottom),
      cornerPaint,
    );

    // Bottom-Right corner
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cornerLength, scanRect.bottom)
        ..lineTo(scanRect.right - borderRadius, scanRect.bottom)
        ..arcToPoint(
          Offset(scanRect.right, scanRect.bottom - borderRadius),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(scanRect.right, scanRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CutoutOverlayPainter oldDelegate) {
    return oldDelegate.scanRect != scanRect ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.borderColor != borderColor;
  }
}
