import 'package:ar_ctf/features/scan/data/models/tracked_code.dart';
import 'package:ar_ctf/features/scan/presentation/view_models/scan_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Outlines the QR codes in view on top of the camera preview.
///
/// why: codes seen but not yet tracked get a thin outline, to tell missed
/// detections apart from codes the tracking filter still holds back.
class TrackedCodesOverlay extends ConsumerWidget {
  const new({required this.size, super.key});

  /// Size of the cover-fitted camera preview this overlay sits on.
  final Size size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return CustomPaint(
      size: size,
      painter: _OutlinePainter(
        codes: ref.watch(scanViewModelProvider).values.toList(),
        trackedColor: colors.primary,
        pendingColor: colors.tertiary,
      ),
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
