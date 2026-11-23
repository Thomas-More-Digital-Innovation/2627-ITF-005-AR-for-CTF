import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A QR code seen by the camera, with the tracking hysteresis of spec 3.1
/// step 4: tracked after [hitsToTrack] detections, lost after [lostAfter]
/// without one.
@immutable
class TrackedCode {
  const new({
    required this.corners,
    required this.imageSize,
    required this.lastSeen,
    this.hits = 1,
  });

  static const hitsToTrack = 3;
  static const lostAfter = Duration(milliseconds: 250);

  /// Corners in camera-image coordinates, clockwise from the top left.
  final List<Offset> corners;

  final Size imageSize;

  final DateTime lastSeen;
  final int hits;

  bool get isTracked => hits >= hitsToTrack;

  bool isLostAt(DateTime now) => now.difference(lastSeen) > lostAfter;

  TrackedCode seenAgain(List<Offset> corners, Size imageSize, DateTime at) =>
      TrackedCode(
        corners: corners,
        imageSize: imageSize,
        lastSeen: at,
        hits: hits + 1,
      );

  /// Maps the corners onto a view of [viewSize] that shows the camera image
  /// with [BoxFit.cover], centred.
  ///
  /// why: `Barcode.scaleCorners` stretches both axes independently, which is
  /// wrong for a cover-fitted preview (spec 3.1 step 2).
  List<Offset> cornersIn(Size viewSize) {
    final scale = math.max(
      viewSize.width / imageSize.width,
      viewSize.height / imageSize.height,
    );
    final offset = Offset(
      (viewSize.width - imageSize.width * scale) / 2,
      (viewSize.height - imageSize.height * scale) / 2,
    );
    return [for (final corner in corners) corner * scale + offset];
  }
}
