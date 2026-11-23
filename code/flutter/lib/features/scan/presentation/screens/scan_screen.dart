import 'package:ar_ctf/features/scan/presentation/view_models/scan_view_model.dart';
import 'package:ar_ctf/features/scan/presentation/widgets/tracked_codes_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen camera preview that outlines every QR code in view.
class ScanScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: MobileScanner(
        controller: ref.watch(scanViewModelProvider.notifier).controller,
        // ponytail: shows the raw error; replace with the explicit permission
        // and "no camera" flows (spec 3.5) when the scan screen is designed
        errorBuilder: (context, error) => Center(
          child: Text(
            error.errorDetails?.message ?? error.errorCode.message,
            textAlign: TextAlign.center,
          ),
        ),
        overlayBuilder: (context, constraints) =>
            TrackedCodesOverlay(size: constraints.biggest),
      ),
    );
  }
}
