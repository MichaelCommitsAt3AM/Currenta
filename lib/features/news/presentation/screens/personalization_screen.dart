// lib/features/news/presentation/screens/personalization_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/providers.dart';
import '../../domain/entities/news_category.dart';
import 'empty_state_screen.dart';
import 'country_selection_screen.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class PersonalizationScreen extends ConsumerStatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  ConsumerState<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<PersonalizationScreen> {
  final Set<NewsCategory> _selectedCategories = {};
  final Set<NewsSubCategory> _selectedSubCategories = {};
  String? _selectedCountry;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final interests = await repository.getUserInterests();
      final subInterests = await repository.getUserSubInterests();
      final preferredCountry = await repository.getPreferredCountry();
      
      if (mounted) {
        setState(() {
          // First, load all specific sub-interests
          for (final subName in subInterests) {
             try {
                final subCategory = NewsSubCategory.values.firstWhere(
                  (s) => s.name == subName,
                );
                _selectedSubCategories.add(subCategory);
             } catch (_) {}
          }

          // Then, load categories and apply smart defaults for missing sub-interests
          for (final catName in interests) {
            final category = NewsCategory.values.firstWhere(
              (c) => c.name == catName,
              orElse: () => NewsCategory.world,
            );
            _selectedCategories.add(category);
            
            // Per user request: If a category is selected but has NO stored sub-interests,
            // we automatically select all its sub-categories.
            final categorySubNames = category.subCategories.toSet();
            final hasStoredSubInterests = categorySubNames.any(
              (sub) => _selectedSubCategories.contains(sub)
            );
            
            if (!hasStoredSubInterests && categorySubNames.isNotEmpty) {
              _selectedSubCategories.addAll(category.subCategories);
            }
          }
          
          _selectedCountry = preferredCountry;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load interests: $e')),
        );
      }
    }
  }

  void _toggleCategory(NewsCategory category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
        // Automatically deselect all sub-categories for this category (Smart Defaults)
        for (final sub in category.subCategories) {
          _selectedSubCategories.remove(sub);
        }
      } else {
        _selectedCategories.add(category);
        // Automatically select all sub-categories for this category (Smart Defaults)
        for (final sub in category.subCategories) {
          _selectedSubCategories.add(sub);
        }
      }
    });
  }

  void _toggleSubCategory(NewsSubCategory subCategory) {
    setState(() {
      if (_selectedSubCategories.contains(subCategory)) {
        _selectedSubCategories.remove(subCategory);
      } else {
        _selectedSubCategories.add(subCategory);
      }
    });
  }

  Future<void> _onSave() async {
    if (_selectedCategories.length < 3) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 3 main topics')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      
      // Save Main Categories
      await repository.clearUserInterests();
      await repository.saveUserInterests(_selectedCategories.map((e) => e.name).toList());
      
      // Save Sub Categories
      await repository.clearUserSubInterests();
      if (_selectedSubCategories.isNotEmpty) {
        // Only save sub-categories whose parents are selected
        final validSubCategories = _selectedSubCategories.where((sub) {
          return NewsCategory.values.any((cat) => 
            _selectedCategories.contains(cat) && cat.subCategories.contains(sub)
          );
        }).map((e) => e.name).toList();
        
        if (validSubCategories.isNotEmpty) {
          await repository.saveUserSubInterests(validSubCategories);
        }
      }
      
      // Save Country Preference
      if (_selectedCountry != null) {
        await repository.savePreferredCountry(_selectedCountry!);
      }
      
      if (mounted) {
        // Refresh the global country and interests preference
        ref.read(authNotifierProvider.notifier).refreshPreferredCountry();
        ref.read(authNotifierProvider.notifier).refreshInterests();
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interests updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save interests: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Allow both regular and guest users to personalize
    if (!authState.isAuthenticated && !authState.isAnonymous) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0C14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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
          message: 'Unable to establish a secure session. Please check your connection or sign in.',
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

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
        : Column(
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
                        final result = await Navigator.push<({String? code})?>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CountrySelectionScreen(initialCountry: _selectedCountry),
                          ),
                        );
                        if (mounted && result != null) {
                           setState(() => _selectedCountry = result.code);
                        }
                      },
                        // Actually, looking at my screen, I always pop with a value when a list item is tapped.
                        // If they pop via back button, it returns null by default in Flutter.
                        // I'll use a slightly safer pattern.
                      // The original code had an extra closing brace here. Removing it.
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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

              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: NewsCategory.values.length,
                  itemBuilder: (context, index) {
                    final cat = NewsCategory.values[index];
                    final isSelected = _selectedCategories.contains(cat);
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _toggleCategory(cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF6C63FF)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF6C63FF).withValues(alpha: 0.8)
                                    : Colors.white.withValues(alpha: 0.1),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(cat.emoji,
                                    style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  cat.displayName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Colors.white, size: 20)
                                else
                                  Icon(Icons.add_circle_outline, color: Colors.white.withValues(alpha: 0.3), size: 20),
                              ],
                            ),
                          ),
                        ),
                        if (isSelected && cat.subCategories.isNotEmpty) 
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                                  child: Text(
                                    'Fine-tune (Optional)',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: cat.subCategories.map((sub) {
                                    final isSubSelected = _selectedSubCategories.contains(sub);
                                    return GestureDetector(
                                      onTap: () => _toggleSubCategory(sub),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: isSubSelected 
                                              ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSubSelected 
                                                ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                                                : Colors.white.withValues(alpha: 0.1),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isSubSelected)
                                              const Padding(
                                                padding: EdgeInsets.only(right: 6),
                                                child: Icon(Icons.check, size: 12, color: Colors.white),
                                              )
                                            else
                                              Padding(
                                                padding: const EdgeInsets.only(right: 6),
                                                child: Icon(Icons.remove_circle_outline, 
                                                  size: 12, color: Colors.white.withValues(alpha: 0.3)),
                                              ),
                                            Text(
                                              sub.displayName,
                                              style: TextStyle(
                                                color: isSubSelected ? Colors.white : Colors.white54,
                                                fontSize: 12,
                                                fontWeight: isSubSelected ? FontWeight.w600 : FontWeight.normal,
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
                          ),
                      ],
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    disabledBackgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Preferences',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),
              ),
            ],
          ),
    );
  }
}
