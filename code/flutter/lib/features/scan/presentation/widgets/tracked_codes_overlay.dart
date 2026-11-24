import 'package:ar_ctf/features/scan/data/models/tracked_code.dart';
import 'package:ar_ctf/features/scan/presentation/view_models/scan_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// why: codes seen but not yet tracked get a thin outline, to tell missed
/// detections apart from codes the tracking filter still holds back.
class TrackedCodesOverlay extends ConsumerWidget {
  const new({required this.size, super.key});

  static const _flagSize = 96.0;

  final Size size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final codes = ref.watch(scanViewModelProvider).values.toList();
    // why: shrinks the icon's box to the unit square the homography maps from
    final toUnitSquare = Matrix4.diagonal3Values(
      1 / _flagSize,
      1 / _flagSize,
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
        // ponytail: a flat icon on the code validates the corner mapping
        // (spec 3.1 milestone); replaced by the projected flag mesh (step 6)
        for (final code in codes)
          if (code.isTracked)
            if (code.homographyIn(size) case final homography?)
              Positioned(
                left: 0,
                top: 0,
                child: Transform(
                  transform: homography.multiplied(toUnitSquare),
                  child: Icon(
                    Icons.flag,
                    size: _flagSize,
                    color: colors.primary,
                  ),
                ),
              ),
      ],
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
