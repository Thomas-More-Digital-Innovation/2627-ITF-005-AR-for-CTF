import 'package:ar_ctf/features/scan/data/models/tracked_code.dart';
import 'package:flutter/rendering.dart';
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

  group('homographyIn', () {
    // a trapezoid, so the map is projective and not affine
    const quad = [
      Offset(20, 10),
      Offset(80, 10),
      Offset(100, 90),
      Offset(0, 90),
    ];
    // view equals image size, so cornersIn is the identity
    const view = Size(100, 100);
    final homography = TrackedCode(
      corners: quad,
      imageSize: view,
      lastSeen: t0,
    ).homographyIn(view)!;

    Matcher near(Offset expected) => isA<Offset>()
        .having((o) => o.dx, 'dx', closeTo(expected.dx, 1e-9))
        .having((o) => o.dy, 'dy', closeTo(expected.dy, 1e-9));

    test('maps the unit square corners onto the code corners', () {
      const unit = [Offset.zero, Offset(1, 0), Offset(1, 1), Offset(0, 1)];
      for (var i = 0; i < unit.length; i++) {
        expect(MatrixUtils.transformPoint(homography, unit[i]), near(quad[i]));
      }
    });

    test('maps the square centre onto the crossing of the diagonals', () {
      // diagonals (20,10)-(100,90) and (80,10)-(0,90) cross at (50,40)
      expect(
        MatrixUtils.transformPoint(homography, const Offset(0.5, 0.5)),
        near(const Offset(50, 40)),
      );
    });

    test('is null for collinear corners', () {
      const line = [Offset.zero, Offset(1, 0), Offset(2, 0), Offset(3, 0)];
      expect(
        TrackedCode(
          corners: line,
          imageSize: view,
          lastSeen: t0,
        ).homographyIn(view),
        isNull,
      );
    });
  });
}
