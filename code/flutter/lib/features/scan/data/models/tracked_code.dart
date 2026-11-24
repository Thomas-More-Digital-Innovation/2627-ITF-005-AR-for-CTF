import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// A QR code seen by the camera, with the tracking hysteresis of spec 3.1
/// step 4: tracked after [hitsToTrack] detections, lost after [lostAfter]
/// without one.
@immutable
class TrackedCode {
  const new({
    required this.corners,
    required this.imageSize,
    required this.lastSeen,
    this.velocities = _still,
    this.hits = 1,
  });

  static const hitsToTrack = 3;
  static const lostAfter = Duration(milliseconds: 250);
  static const List<Offset> _still = [
    Offset.zero,
    Offset.zero,
    Offset.zero,
    Offset.zero,
  ];

  final List<Offset> corners;
  final List<Offset> velocities;
  final Size imageSize;
  final DateTime lastSeen;
  final int hits;

  bool get isTracked => hits >= hitsToTrack;

  bool isLostAt(DateTime now) => now.difference(lastSeen) > lostAfter;

  TrackedCode seenAgain(
    List<Offset> corners,
    List<Offset> velocities,
    DateTime at,
  ) => TrackedCode(
    corners: corners,
    imageSize: imageSize,
    lastSeen: at,
    velocities: velocities,
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

  /// Projective map from the unit square onto the corners in a view of
  /// [viewSize] (spec 3.1 step 5), embedded in a [Matrix4] for `Transform`.
  /// Null when the corners are degenerate.
  ///
  /// how: closed-form square-to-quad mapping (Heckbert, "Fundamentals of
  /// Texture Mapping and Image Warping", 1989), so no linear solve is needed.
  Matrix4? homographyIn(Size viewSize) {
    final [p0, p1, p2, p3] = cornersIn(viewSize);
    final d1 = p1 - p2;
    final d2 = p3 - p2;
    final d3 = p0 - p1 + p2 - p3;
    final den = d1.dx * d2.dy - d1.dy * d2.dx;
    if (den == 0) return null;
    final g = (d3.dx * d2.dy - d3.dy * d2.dx) / den;
    final h = (d1.dx * d3.dy - d1.dy * d3.dx) / den;
    // why: column-major; z passes through so the 3x3 map stays exact at z = 0
    return Matrix4(
      p1.dx - p0.dx + g * p1.dx,
      p1.dy - p0.dy + g * p1.dy,
      0,
      g,
      p3.dx - p0.dx + h * p3.dx,
      p3.dy - p0.dy + h * p3.dy,
      0,
      h,
      0,
      0,
      1,
      0,
      p0.dx,
      p0.dy,
      0,
      1,
    );
  }
}
