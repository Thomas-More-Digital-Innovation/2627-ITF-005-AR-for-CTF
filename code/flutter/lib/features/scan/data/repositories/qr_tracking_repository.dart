import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'qr_tracking_repository.g.dart';

/// The QR codes in one camera frame: payload → corners in image coordinates.
typedef QrFrame = ({Map<String, List<Offset>> codes, Size imageSize});

/// Detects QR codes on every camera frame, with their corner points.
class QrTrackingRepository {
  new(this.controller);

  final MobileScannerController controller;

  /// Frames with at least one QR code. Frames without codes emit nothing.
  Stream<QrFrame> get frames => controller.barcodes
      // why: corners cannot be mapped without the image size
      .where((capture) => !capture.size.isEmpty)
      .map(
        (capture) => (
          imageSize: capture.size,
          codes: {
            for (final barcode in capture.barcodes)
              if (barcode.rawValue case final payload?
                  when barcode.corners.length == 4)
                payload: barcode.corners,
          },
        ),
      );
}

@riverpod
QrTrackingRepository qrTrackingRepository(Ref ref) {
  final controller = MobileScannerController(
    // why: tracking needs every frame; the other speeds drop or throttle them
    detectionSpeed: DetectionSpeed.unrestricted,
    formats: const [BarcodeFormat.qrCode],
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  return QrTrackingRepository(controller);
}
