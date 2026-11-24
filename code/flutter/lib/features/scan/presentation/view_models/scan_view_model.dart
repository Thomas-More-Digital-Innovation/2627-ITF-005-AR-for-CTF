import 'dart:async';
import 'dart:math' as math;

import 'package:ar_ctf/features/scan/data/models/tracked_code.dart';
import 'package:ar_ctf/features/scan/data/repositories/qr_tracking_repository.dart';
import 'package:flutter/painting.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scan_view_model.g.dart';

/// The QR codes in view, keyed by payload.
@riverpod
class ScanViewModel extends _$ScanViewModel {
  static const _lostCheckInterval = Duration(milliseconds: 50);

  @override
  Map<String, TrackedCode> build() {
    final frames = ref
        .watch(qrTrackingRepositoryProvider)
        .frames
        .listen(
          (frame) => state = track(
            state,
            frame.codes,
            frame.imageSize,
            DateTime.now(),
          ),
        );
    // why: the scanner emits nothing for frames without codes, so lost codes
    // are only noticed by checking the clock
    final lostCheck = Timer.periodic(_lostCheckInterval, (_) {
      final kept = dropLost(state, DateTime.now());
      if (kept.length != state.length) state = kept;
    });
    ref.onDispose(() {
      lostCheck.cancel();
      unawaited(frames.cancel());
    });
    return const {};
  }

  // why: the preview widget needs the controller, and widgets only talk to
  // view models
  MobileScannerController get controller =>
      ref.read(qrTrackingRepositoryProvider).controller;
}

Map<String, TrackedCode> dropLost(
  Map<String, TrackedCode> codes,
  DateTime now,
) => {
  for (final MapEntry(:key, :value) in codes.entries)
    if (!value.isLostAt(now)) key: value,
};

/// A code that was lost starts counting from one again. Corners of a code
/// seen again are smoothed with [oneEuro].
Map<String, TrackedCode> track(
  Map<String, TrackedCode> codes,
  Map<String, List<Offset>> detections,
  Size imageSize,
  DateTime now,
) {
  final kept = dropLost(codes, now);
  return {
    ...kept,
    for (final MapEntry(key: payload, value: raw) in detections.entries)
      payload: switch (kept[payload]) {
        // why: corners from another image size are in other coordinates
        final previous? when previous.imageSize == imageSize => _smoothed(
          previous,
          raw,
          now,
        ),
        _ => TrackedCode(corners: raw, imageSize: imageSize, lastSeen: now),
      },
  };
}

TrackedCode _smoothed(TrackedCode previous, List<Offset> raw, DateTime now) {
  final dt = now.difference(previous.lastSeen);
  final corners = [
    for (var i = 0; i < raw.length; i++)
      oneEuro(
        (position: previous.corners[i], velocity: previous.velocities[i]),
        raw[i],
        dt,
      ),
  ];
  return previous.seenAgain(
    [for (final c in corners) c.position],
    [for (final c in corners) c.velocity],
    now,
  );
}

/// One corner after smoothing: its filtered position and filtered speed.
typedef SmoothedCorner = ({Offset position, Offset velocity});

// TODO: tuned on one phone; retune when testing more devices
const _minCutoffHz = 1.0;
const _beta = 0.007;
const _derivativeCutoffHz = 1.0;

/// One step of the One Euro filter (Casiez et al., 2012) for one corner:
/// strong smoothing while the corner is still, little lag while it moves.
SmoothedCorner oneEuro(SmoothedCorner previous, Offset raw, Duration dt) {
  final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
  if (seconds <= 0) return previous;
  final velocity = Offset.lerp(
    previous.velocity,
    (raw - previous.position) / seconds,
    _alpha(_derivativeCutoffHz, seconds),
  )!;
  final cutoff = _minCutoffHz + _beta * velocity.distance;
  return (
    position: Offset.lerp(previous.position, raw, _alpha(cutoff, seconds))!,
    velocity: velocity,
  );
}

double _alpha(double cutoffHz, double seconds) =>
    1 / (1 + 1 / (2 * math.pi * cutoffHz * seconds));
