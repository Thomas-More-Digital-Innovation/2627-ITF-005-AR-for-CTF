// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The QR codes in view, keyed by payload.

@ProviderFor(ScanViewModel)
final scanViewModelProvider = ScanViewModelProvider._();

/// The QR codes in view, keyed by payload.
final class ScanViewModelProvider
    extends $NotifierProvider<ScanViewModel, Map<String, TrackedCode>> {
  /// The QR codes in view, keyed by payload.
  ScanViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scanViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scanViewModelHash();

  @$internal
  @override
  ScanViewModel create() => ScanViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, TrackedCode> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, TrackedCode>>(value),
    );
  }
}

String _$scanViewModelHash() => r'32c5b491c933bcf6dc55904c769f25b2b52c823e';

/// The QR codes in view, keyed by payload.

abstract class _$ScanViewModel extends $Notifier<Map<String, TrackedCode>> {
  Map<String, TrackedCode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<Map<String, TrackedCode>, Map<String, TrackedCode>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, TrackedCode>, Map<String, TrackedCode>>,
              Map<String, TrackedCode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
