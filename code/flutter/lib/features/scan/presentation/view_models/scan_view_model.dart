import 'dart:async';

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

/// A code that was lost starts counting from one again.
Map<String, TrackedCode> track(
  Map<String, TrackedCode> codes,
  Map<String, List<Offset>> detections,
  Size imageSize,
  DateTime now,
) {
  final kept = dropLost(codes, now);
  return {
    ...kept,
    for (final MapEntry(key: payload, value: corners) in detections.entries)
      payload:
          kept[payload]?.seenAgain(corners, imageSize, now) ??
          TrackedCode(corners: corners, imageSize: imageSize, lastSeen: now),
  };
}
