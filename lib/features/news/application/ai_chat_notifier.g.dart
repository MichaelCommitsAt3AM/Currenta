// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_chat_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiChatNotifierHash() => r'7e4e2326dcb4ca5d5869dac6f1db3bcae79787b4';

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
    extends BuildlessAutoDisposeNotifier<List<ChatMessage>> {
  late final String articleId;

  List<ChatMessage> build(
    String articleId,
  );
}

/// See also [AiChatNotifier].
@ProviderFor(AiChatNotifier)
const aiChatNotifierProvider = AiChatNotifierFamily();

/// See also [AiChatNotifier].
class AiChatNotifierFamily extends Family<List<ChatMessage>> {
  /// See also [AiChatNotifier].
  const AiChatNotifierFamily();

  /// See also [AiChatNotifier].
  AiChatNotifierProvider call(
    String articleId,
  ) {
    return AiChatNotifierProvider(
      articleId,
    );
  }

  @override
  AiChatNotifierProvider getProviderOverride(
    covariant AiChatNotifierProvider provider,
  ) {
    return call(
      provider.articleId,
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
    extends AutoDisposeNotifierProviderImpl<AiChatNotifier, List<ChatMessage>> {
  /// See also [AiChatNotifier].
  AiChatNotifierProvider(
    String articleId,
  ) : this._internal(
          () => AiChatNotifier()..articleId = articleId,
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
        );

  AiChatNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.articleId,
  }) : super.internal();

  final String articleId;

  @override
  List<ChatMessage> runNotifierBuild(
    covariant AiChatNotifier notifier,
  ) {
    return notifier.build(
      articleId,
    );
  }

  @override
  Override overrideWith(AiChatNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: AiChatNotifierProvider._internal(
        () => create()..articleId = articleId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        articleId: articleId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<AiChatNotifier, List<ChatMessage>>
      createElement() {
    return _AiChatNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AiChatNotifierProvider && other.articleId == articleId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, articleId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AiChatNotifierRef on AutoDisposeNotifierProviderRef<List<ChatMessage>> {
  /// The parameter `articleId` of this provider.
  String get articleId;
}

class _AiChatNotifierProviderElement extends AutoDisposeNotifierProviderElement<
    AiChatNotifier, List<ChatMessage>> with AiChatNotifierRef {
  _AiChatNotifierProviderElement(super.provider);

  @override
  String get articleId => (origin as AiChatNotifierProvider).articleId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
