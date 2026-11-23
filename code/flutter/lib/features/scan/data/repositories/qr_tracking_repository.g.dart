// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_tracking_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(qrTrackingRepository)
final qrTrackingRepositoryProvider = QrTrackingRepositoryProvider._();

final class QrTrackingRepositoryProvider
    extends
        $FunctionalProvider<
          QrTrackingRepository,
          QrTrackingRepository,
          QrTrackingRepository
        >
    with $Provider<QrTrackingRepository> {
  QrTrackingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrTrackingRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrTrackingRepositoryHash();

  @$internal
  @override
  $ProviderElement<QrTrackingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  QrTrackingRepository create(Ref ref) {
    return qrTrackingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrTrackingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrTrackingRepository>(value),
    );
  }
}

String _$qrTrackingRepositoryHash() =>
    r'8e3dceb9a484dfc71e953f7fd194e7d799a0f00a';
