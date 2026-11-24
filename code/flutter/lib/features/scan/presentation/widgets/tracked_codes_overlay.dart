import 'package:ar_ctf/features/scan/data/models/tracked_code.dart';
import 'package:ar_ctf/features/scan/presentation/view_models/scan_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Draws the flag of spec 3.1 step 6 on every tracked code: a shadow lying
/// on the paper and a flag standing upright on the screen, its foot on the
/// code's centre.
///
/// why: codes seen but not yet tracked get a thin outline, to tell missed
/// detections apart from codes the tracking filter still holds back.
class TrackedCodesOverlay extends ConsumerWidget {
  const new({required this.size, super.key});

  static const _flagScale = 1.5;

  /// Foot of the pole in the `Icons.flag` glyph, as a fraction of its box
  /// (the 24-unit glyph has its pole at x 5-7, ending at y 21).
  static const _flagFoot = Offset(6 / 24, 21 / 24);

  static const _shadowBox = 100.0;
  static const _shadowInset = 25.0;
  static const _shadowOpacity = 0.4;

  final Size size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final codes = ref.watch(scanViewModelProvider).values.toList();
    final toUnitSquare = Matrix4.diagonal3Values(
      1 / _shadowBox,
      1 / _shadowBox,
      1,
    );
    return Stack(
      children: [
        CustomPaint(
          size: size,
          painter: _OutlinePainter(
            codes: codes,
            trackedColor: colors.primary,
            pendingColor: colors.tertiary,
          ),
        ),
        for (final code in codes)
          if (code.isTracked)
            if (code.homographyIn(size) case final homography?) ...[
              Positioned(
                left: 0,
                top: 0,
                child: Transform(
                  transform: homography.multiplied(toUnitSquare),
                  child: SizedBox.square(
                    dimension: _shadowBox,
                    child: Padding(
                      padding: const EdgeInsets.all(_shadowInset),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.shadow.withValues(
                            alpha: _shadowOpacity,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _StandingFlag(
                foot: MatrixUtils.transformPoint(
                  homography,
                  const Offset(0.5, 0.5),
                ),
                flagSize: code.sideIn(size) * _flagScale,
                color: colors.primary,
              ),
            ],
      ],
    );
  }
}

class _StandingFlag extends StatelessWidget {
  const new({required this.foot, required this.flagSize, required this.color});

  final Offset foot;
  final double flagSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final topLeft = foot - TrackedCodesOverlay._flagFoot * flagSize;
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      child: Icon(Icons.flag, size: flagSize, color: color),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  new({
    required this.codes,
    required this.trackedColor,
    required this.pendingColor,
  });

  static const _trackedStrokeWidth = 4.0;
  static const _pendingStrokeWidth = 1.5;

  final List<TrackedCode> codes;
  final Color trackedColor;
  final Color pendingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final tracked = Paint()
      ..color = trackedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _trackedStrokeWidth;
    final pending = Paint()
      ..color = pendingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _pendingStrokeWidth;
    for (final code in codes) {
      canvas.drawPath(
        Path()..addPolygon(code.cornersIn(size), true),
        code.isTracked ? tracked : pending,
      );
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) =>
      oldDelegate.codes != codes ||
      oldDelegate.trackedColor != trackedColor ||
      oldDelegate.pendingColor != pendingColor;
}
