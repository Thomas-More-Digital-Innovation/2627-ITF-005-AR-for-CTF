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
}
