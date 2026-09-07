// lib/features/news/presentation/screens/personalization_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/taxonomy/taxonomy.dart';
import '../../domain/entities/news_category.dart';
import '../../domain/subcategory_preferences.dart';
import 'empty_state_screen.dart';
import 'country_selection_screen.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../application/news_feed_notifier.dart';
import '../../../../core/utils/snackbar_utils.dart';

class PersonalizationScreen extends ConsumerStatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  ConsumerState<PersonalizationScreen> createState() =>
      _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<PersonalizationScreen> {
  final Set<NewsCategory> _selectedCategories = {};
  final Set<String> _selectedSubSlugs = {};
  String? _selectedCountry;

  // Track initial state to detect changes
  final Set<NewsCategory> _initialCategories = {};
  final Set<String> _initialSubSlugs = {};
  String? _initialCountry;

  /// Muted L3 (dotted) slugs from the "Not interested" flow. The screen only
  /// manages L2 mutes, so these are preserved verbatim when saving.
  List<String> _preservedMutes = const [];

  bool _isLoading = true;
  bool _isSaving = false;
  int _expandedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    try {
      await Taxonomy.ensureLoaded();
      final taxonomy = Taxonomy.instance;
      final repository = ref.read(authRepositoryProvider);
      final interests = await repository.getUserInterests();
      final muted = await repository.getMutedSubCategories();
      final preferredCountry = await repository.getPreferredCountry();

      if (!mounted) return;
      setState(() {
        // The screen manages L2 mutes only; L3 ("Not interested") mutes are
        // kept aside and re-written untouched on save.
        _preservedMutes = muted.where((m) => m.contains('.')).toList();
        final mutedL2 = muted.where((m) => !m.contains('.')).toSet();

        for (final catName in interests) {
          final category = NewsCategory.values.firstWhere(
            (c) => c.name == catName,
            orElse: () => NewsCategory.world,
          );
          _selectedCategories.add(category);
          if (category == NewsCategory.local) continue;

          // A subcategory is "on" unless the user has muted it. Nothing muted
          // for a category → every subcategory selected (the smart default).
          for (final slug in taxonomy.subcategorySlugsFor(category.name)) {
            if (!mutedL2.contains(slug)) _selectedSubSlugs.add(slug);
          }
        }

        _selectedCountry = preferredCountry;

        // Capture initial state for change tracking
        _initialCategories
          ..clear()
          ..addAll(_selectedCategories);
        _initialSubSlugs
          ..clear()
          ..addAll(_selectedSubSlugs);
        _initialCountry = _selectedCountry;

        _isLoading = false;

        // Per user request: categories remain collapsed by default.
        _expandedIndex = -1;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.showError(context, 'Failed to load interests: $e');
      }
    }
  }

  List<TaxonomyNode> _subNodesFor(NewsCategory cat) => cat == NewsCategory.local
      ? const []
      : Taxonomy.instance.subcategoriesFor(cat.name);

  void _toggleExpansion(int index) {
    if (NewsCategory.values[index] == NewsCategory.local) return;
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = -1; // Collapse if clicking the same one
      } else {
        _expandedIndex = index;
      }
    });
  }

  void _toggleCategory(NewsCategory category) {
    setState(() {
      final subs = category == NewsCategory.local
          ? const <String>[]
          : Taxonomy.instance.subcategorySlugsFor(category.name);
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
        _selectedSubSlugs.removeAll(subs);
      } else {
        // Re-enabling a category starts it fully selected (smart default).
        _selectedCategories.add(category);
        _selectedSubSlugs.addAll(subs);
      }
    });
  }

  void _toggleSubCategory(String slug) {
    setState(() {
      if (_selectedSubSlugs.contains(slug)) {
        _selectedSubSlugs.remove(slug);
      } else {
        _selectedSubSlugs.add(slug);

        // Auto-select the parent category if a sub-category is picked.
        final parent = NewsCategory.values.firstWhere(
          (c) =>
              c != NewsCategory.local &&
              Taxonomy.instance.subcategorySlugsFor(c.name).contains(slug),
          orElse: () => NewsCategory.world,
        );
        _selectedCategories.add(parent);
      }
    });
  }

  bool get _hasChanges {
    return _initialCountry != _selectedCountry ||
        !setEquals(_initialCategories, _selectedCategories) ||
        !setEquals(_initialSubSlugs, _selectedSubSlugs);
  }

  Future<void> _onSave() async {
    if (_selectedCategories.length < 3) {
      AppSnackbar.showError(context, 'Please select at least 3 main topics');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final authBeforeSave = ref.read(authNotifierProvider);
      final prevCountry = authBeforeSave.preferredCountry;

      // Save Main Categories
      await repository.clearUserInterests();
      await repository
          .saveUserInterests(_selectedCategories.map((e) => e.name).toList());

      // Subcategory preferences. Selected chips are a soft ranking boost
      // (user_sub_interests); chips de-selected under an enabled category are a
      // HARD feed filter (user_muted_subcategories — the same table the
      // "Not interested" mute sheet writes to). L3 "Not interested" mutes are
      // carried through untouched.
      final taxonomy = Taxonomy.instance;
      final boost = SubcategoryPreferences.boostSlugs(
        taxonomy: taxonomy,
        enabledCategories: _selectedCategories,
        selectedSlugs: _selectedSubSlugs,
      );
      final mutedL2 = SubcategoryPreferences.mutedL2(
        taxonomy: taxonomy,
        enabledCategories: _selectedCategories,
        selectedSlugs: _selectedSubSlugs,
      );

      await repository.clearUserSubInterests();
      if (boost.isNotEmpty) {
        await repository.saveUserSubInterests(boost.toList());
      }
      await repository
          .replaceMutedSubCategories([..._preservedMutes, ...mutedL2]);

      // Save Country Preference
      if (_selectedCountry != null) {
        await repository.savePreferredCountry(_selectedCountry!);
      }

      if (mounted) {
        // Refresh the global country and interests preference
        await ref.read(authNotifierProvider.notifier).refreshPreferredCountry();
        await ref.read(authNotifierProvider.notifier).refreshInterests();

        final nextCountry = _selectedCountry;

        // Selective Cache Management:
        // When the country changes, we only wipe the "local" category articles
        // to ensure the Local tab is regional, while preserving other interests.
        if (nextCountry != prevCountry && nextCountry != null) {
          debugPrint(
              '[Personalization] Country changed. Clearing local news from cache.');
          await ref
              .read(newsRepositoryProvider)
              .deleteArticlesByCategory('local');
        }

        // 1. Surgical wipe of the articles cache (preserves bookmarks/likes).
        // We use clearCache here instead of clearFeed if there are major changes
        // to ensure the user gets a completely fresh start.
        final newsRepo = ref.read(newsRepositoryProvider);
        await newsRepo.clearRemoteUserState();
        await newsRepo.clearCache();

        // 2. Reset the current scroll position.
        await ref
            .read(localPersistenceRepositoryProvider)
            .saveCurrentArticleId(null);
        await ref
            .read(localPersistenceRepositoryProvider)
            .saveLastForYouArticleId(null);

        // 3. Mark the feed as needing a 'Fake Shimmer' refresh on return.
        ref.read(needsFeedRefreshProvider.notifier).state = true;
        
        // 4. Force invalidate the notifier so the background sync starts NOW.
        ref.invalidate(newsFeedNotifierProvider);

        if (mounted) {
          Navigator.pop(context);
          AppSnackbar.showSuccess(context, 'Interests updated successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackbar.showError(context, 'Failed to save interests: $e');
      }
    }
  }

  Future<bool> _showExitConfirmation() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161822),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF4D4D),
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unsaved Changes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You have made changes to your preferences. Are you sure you want to discard them?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                    child: const Text(
                      'Keep Editing',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D4D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Discard',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }


  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Wait for the auth profile to load (resolving anonymous session, interests, etc.)
    if (!authState.isProfileLoaded || _isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0C14),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    // Only show error if we genuinely failed to establish ANY session (even guest)
    if (!authState.isAuthenticated && !authState.isAnonymous) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0C14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Personalization',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: EmptyStateScreen(
          title: 'Session Error',
          message:
              'Unable to establish a secure session. Please check your connection or sign in.',
          buttonLabel: 'Sign In',
          icon: Icons.error_outline_rounded,
          onRetry: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      );
    }

    return PopScope(
      canPop: !_hasChanges || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0C14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () async {
              if (_hasChanges && !_isSaving) {
                final shouldPop = await _showExitConfirmation();
                if (shouldPop && context.mounted) {
                  Navigator.pop(context);
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
        title: const Text(
          'Personalization',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120), // Space for button
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Text(
                            'Choose your preferred region for local news and select at least 3 topics to personalize your feed.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ),

                        // Country Selection
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Local News Region',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () async {
                                  if (!_selectedCategories.contains(NewsCategory.local)) {
                                    AppSnackbar.showError(context,
                                        'Please select Local News category first to set your region');
                                    return;
                                  }
                                  final result = await Navigator.push<({String? code})?>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CountrySelectionScreen(
                                          initialCountry: _selectedCountry),
                                    ),
                                  );
                                  if (mounted && result != null) {
                                    setState(() => _selectedCountry = result.code);
                                  }
                                },
                                child: Opacity(
                                  opacity: _selectedCategories.contains(NewsCategory.local)
                                      ? 1.0
                                      : 0.4,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _selectedCountry != null
                                              ? NewsCategory.getCountryEmoji(_selectedCountry!)
                                              : '📍',
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedCountry != null
                                                    ? NewsCategory.getCountryName(_selectedCountry!)
                                                    : 'Detect Automatically',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                'Source local news based on this region',
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.5),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_right_rounded,
                                          color: Colors.white.withValues(alpha: 0.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                          child: Text(
                            'Topics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        // Categories List
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: List.generate(NewsCategory.values.length, (index) {
                              final cat = NewsCategory.values[index];
                              final isSelected = _selectedCategories.contains(cat);
                              final isExpanded = _expandedIndex == index;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleExpansion(index),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: isExpanded
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isExpanded
                                              ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                                              : Colors.white.withValues(alpha: 0.05),
                                          width: isExpanded ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            cat.displayName,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          GestureDetector(
                                            onTap: () => _toggleCategory(cat),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              child: isSelected
                                                  ? const Icon(Icons.check_circle_rounded,
                                                      color: Color(0xFF6C63FF), size: 24)
                                                  : Icon(Icons.radio_button_unchecked_rounded,
                                                      color: Colors.white.withValues(alpha: 0.2),
                                                      size: 24),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          if (cat != NewsCategory.local)
                                            Icon(
                                              isExpanded
                                                  ? Icons.keyboard_arrow_up_rounded
                                                  : Icons.keyboard_arrow_down_rounded,
                                              color: Colors.white.withValues(alpha: 0.2),
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    alignment: Alignment.topCenter,
                                    child: isExpanded && _subNodesFor(cat).isNotEmpty
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, bottom: 24, right: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(bottom: 16, left: 4),
                                                  child: Text(
                                                    'Fine-tune your ${cat.displayName} interest',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.4),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                Wrap(
                                                  spacing: 10,
                                                  runSpacing: 10,
                                                  children: _subNodesFor(cat).map((sub) {
                                                    final isSubSelected =
                                                        _selectedSubSlugs.contains(sub.slug);
                                                    return GestureDetector(
                                                      onTap: () => _toggleSubCategory(sub.slug),
                                                      child: AnimatedContainer(
                                                        duration:
                                                            const Duration(milliseconds: 200),
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 14, vertical: 8),
                                                        decoration: BoxDecoration(
                                                          color: isSubSelected
                                                              ? const Color(0xFF6C63FF)
                                                                  .withValues(alpha: 0.15)
                                                              : Colors.white
                                                                  .withValues(alpha: 0.05),
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(
                                                            color: isSubSelected
                                                                ? const Color(0xFF6C63FF)
                                                                    .withValues(alpha: 0.5)
                                                                : Colors.transparent,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            if (isSubSelected)
                                                              const Padding(
                                                                padding:
                                                                    EdgeInsets.only(right: 6),
                                                                child: Icon(Icons.check,
                                                                    size: 14, color: Colors.white),
                                                              ),
                                                            Text(
                                                              sub.displayName,
                                                              style: TextStyle(
                                                                color: isSubSelected
                                                                    ? Colors.white
                                                                    : Colors.white
                                                                        .withValues(alpha: 0.5),
                                                                fontSize: 13,
                                                                fontWeight: isSubSelected
                                                                    ? FontWeight.w600
                                                                    : FontWeight.normal,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const SizedBox(width: double.infinity, height: 0),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Fixed Bottom Button
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0A0C14),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white10,
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        child: ElevatedButton(
                          onPressed: (_isSaving || !_hasChanges) ? null : _onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF1E202C),
                            disabledForegroundColor: Colors.white.withValues(alpha: 0.2),
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: _hasChanges ? 4 : 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                               : const Text(
                                  'Save Preferences',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w300,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ),
    );
  }
}

