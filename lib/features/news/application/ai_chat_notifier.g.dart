// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_chat_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiChatNotifierHash() => r'67d28e0f5ee4b47e06f9b0f8ac0970662877c8ac';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$AiChatNotifier
    extends BuildlessAutoDisposeNotifier<AiChatState> {
  late final String articleId;
  late final String articleTitle;

  AiChatState build(
    String articleId,
    String articleTitle,
  );
}

/// See also [AiChatNotifier].
@ProviderFor(AiChatNotifier)
const aiChatNotifierProvider = AiChatNotifierFamily();

/// See also [AiChatNotifier].
class AiChatNotifierFamily extends Family<AiChatState> {
  /// See also [AiChatNotifier].
  const AiChatNotifierFamily();

  /// See also [AiChatNotifier].
  AiChatNotifierProvider call(
    String articleId,
    String articleTitle,
  ) {
    return AiChatNotifierProvider(
      articleId,
      articleTitle,
    );
  }

  @override
  AiChatNotifierProvider getProviderOverride(
    covariant AiChatNotifierProvider provider,
  ) {
    return call(
      provider.articleId,
      provider.articleTitle,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'aiChatNotifierProvider';
}

/// See also [AiChatNotifier].
class AiChatNotifierProvider
    extends AutoDisposeNotifierProviderImpl<AiChatNotifier, AiChatState> {
  /// See also [AiChatNotifier].
  AiChatNotifierProvider(
    String articleId,
    String articleTitle,
  ) : this._internal(
          () => AiChatNotifier()
            ..articleId = articleId
            ..articleTitle = articleTitle,
          from: aiChatNotifierProvider,
          name: r'aiChatNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$aiChatNotifierHash,
          dependencies: AiChatNotifierFamily._dependencies,
          allTransitiveDependencies:
              AiChatNotifierFamily._allTransitiveDependencies,
          articleId: articleId,
          articleTitle: articleTitle,
        );

  AiChatNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.articleId,
    required this.articleTitle,
  }) : super.internal();

  final String articleId;
  final String articleTitle;

  @override
  AiChatState runNotifierBuild(
    covariant AiChatNotifier notifier,
  ) {
    return notifier.build(
      articleId,
      articleTitle,
    );
  }

  @override
  Override overrideWith(AiChatNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: AiChatNotifierProvider._internal(
        () => create()
          ..articleId = articleId
          ..articleTitle = articleTitle,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        articleId: articleId,
        articleTitle: articleTitle,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<AiChatNotifier, AiChatState>
      createElement() {
    return _AiChatNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AiChatNotifierProvider &&
        other.articleId == articleId &&
        other.articleTitle == articleTitle;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, articleId.hashCode);
    hash = _SystemHash.combine(hash, articleTitle.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AiChatNotifierRef on AutoDisposeNotifierProviderRef<AiChatState> {
  /// The parameter `articleId` of this provider.
  String get articleId;

  /// The parameter `articleTitle` of this provider.
  String get articleTitle;
}

class _AiChatNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<AiChatNotifier, AiChatState>
    with AiChatNotifierRef {
  _AiChatNotifierProviderElement(super.provider);

  @override
  String get articleId => (origin as AiChatNotifierProvider).articleId;
  @override
  String get articleTitle => (origin as AiChatNotifierProvider).articleTitle;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
