import 'package:ar_ctf/features/scan/data/models/tracked_code.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const corners = [Offset.zero, Offset(10, 0), Offset(10, 10), Offset(0, 10)];
  const imageSize = Size(100, 200);
  final t0 = DateTime(2026);

  group('cornersIn', () {
    TrackedCode code(Size imageSize) =>
        TrackedCode(corners: corners, imageSize: imageSize, lastSeen: t0);

    test('scales uniformly and crops the sides of a wider image', () {
      // 200x100 image in a 100x100 view: scale 1, 50 px cropped left and right
      expect(code(const Size(200, 100)).cornersIn(const Size(100, 100)), [
        const Offset(-50, 0),
        const Offset(-40, 0),
        const Offset(-40, 10),
        const Offset(-50, 10),
      ]);
    });

    test('scales up and crops the top of a taller image', () {
      // 100x200 image in a 200x200 view: scale 2, 100 px cropped top and bottom
      expect(code(imageSize).cornersIn(const Size(200, 200)), [
        const Offset(0, -100),
        const Offset(20, -100),
        const Offset(20, -80),
        const Offset(0, -80),
      ]);
    });
  });
}
