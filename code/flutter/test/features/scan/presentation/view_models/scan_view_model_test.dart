import 'package:ar_ctf/features/scan/data/models/tracked_code.dart';
import 'package:ar_ctf/features/scan/presentation/view_models/scan_view_model.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const corners = [Offset.zero, Offset(10, 0), Offset(10, 10), Offset(0, 10)];
  const imageSize = Size(100, 200);
  final t0 = DateTime(2026);

  Map<String, TrackedCode> seen(int times, {Duration gap = Duration.zero}) {
    var codes = <String, TrackedCode>{};
    for (var i = 0; i < times; i++) {
      codes = track(codes, {'a': corners}, imageSize, t0.add(gap * i));
    }
    return codes;
  }

  group('track', () {
    test('is tracked only after three detections', () {
      expect(seen(2)['a']!.isTracked, isFalse);
      expect(seen(3)['a']!.isTracked, isTrue);
    });

    test('restarts counting after the code was lost', () {
      final codes = seen(3, gap: const Duration(milliseconds: 300));
      expect(codes['a']!.hits, 1);
    });

    test('tracks several codes independently', () {
      final codes = track(
        seen(3),
        {'b': corners},
        imageSize,
        t0.add(const Duration(milliseconds: 10)),
      );
      expect(codes['a']!.isTracked, isTrue);
      expect(codes['b']!.isTracked, isFalse);
    });
  });

  group('dropLost', () {
    test('keeps a code up to the lost timeout and drops it after', () {
      final codes = seen(1);
      expect(dropLost(codes, t0.add(TrackedCode.lostAfter)), contains('a'));
      expect(
        dropLost(codes, t0.add(const Duration(milliseconds: 251))),
        isEmpty,
      );
    });
  });

  group('track smoothing', () {
    const moved = [
      Offset(10, 0),
      Offset(20, 0),
      Offset(20, 10),
      Offset(10, 10),
    ];

    test('a new code keeps its raw corners', () {
      expect(seen(1)['a']!.corners, corners);
    });

    test('a code seen again lands between its old and new corners', () {
      final codes = track(
        seen(1),
        {'a': moved},
        imageSize,
        t0.add(const Duration(milliseconds: 33)),
      );
      final dx = codes['a']!.corners.first.dx;
      expect(dx, greaterThan(0));
      expect(dx, lessThan(10));
    });

    test('restarts from the raw corners when the image size changes', () {
      final codes = track(
        seen(1),
        {'a': moved},
        const Size(200, 100),
        t0.add(const Duration(milliseconds: 33)),
      );
      expect(codes['a']!.corners, moved);
    });
  });

  group('oneEuro', () {
    const frame = Duration(milliseconds: 33);
    const start = (position: Offset(50, 50), velocity: Offset.zero);

    test('keeps a still corner steady under one pixel of noise', () {
      var corner = start;
      for (var i = 0; i < 30; i++) {
        final previous = corner.position;
        final noise = i.isEven ? 1.0 : -1.0;
        corner = oneEuro(corner, Offset(50 + noise, 50), frame);
        expect((corner.position - previous).distance, lessThan(0.5));
      }
    });

    test('follows a 100 px jump within 10 frames', () {
      var corner = start;
      for (var i = 0; i < 10; i++) {
        corner = oneEuro(corner, const Offset(150, 50), frame);
      }
      expect(corner.position.dx, closeTo(150, 2));
    });

    test('keeps the previous state when no time has passed', () {
      expect(oneEuro(start, const Offset(150, 50), Duration.zero), start);
    });
  });
}
