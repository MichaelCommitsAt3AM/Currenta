// lib/features/auth/presentation/screens/personalization_conflict_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../news/domain/entities/news_category.dart';
import '../../application/auth_notifier.dart';

class PersonalizationConflictScreen extends ConsumerStatefulWidget {
  const PersonalizationConflictScreen({
    super.key,
    required this.guestData,
    required this.accountData,
  });

  final Map<String, dynamic> guestData;
  final Map<String, dynamic> accountData;

  @override
  ConsumerState<PersonalizationConflictScreen> createState() => _PersonalizationConflictScreenState();
}

class _PersonalizationConflictScreenState extends ConsumerState<PersonalizationConflictScreen> {
  bool _isGuestSelected = true;

  @override
  Widget build(BuildContext context) {
    // Safely extract interests
    final guestInterests = _safeList(widget.guestData['interests']);
    final accountInterests = _safeList(widget.accountData['interests']);
    
    // Safely extract country codes
    final guestCountry = widget.guestData['country'] as String? ?? widget.guestData['guest_country'] as String?;
    final accountCountry = widget.accountData['country'] as String? ?? widget.accountData['account_country'] as String?;

    const primaryColor = Color(0xFF6C63FF);
    const backgroundColor = Color(0xFF0A0C14);
    const onSurfaceVariant = Color(0xFF8890B5);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hero Section
              const Text(
                'Personalization Conflict',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(
                width: 280,
                child: Text(
                  'We found existing news preferences on your account. Please select which profile you want to keep.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Account Cards
              _AccountCard(
                title: 'Current Guest',
                email: 'Guest Session',
                isSelected: _isGuestSelected,
                interests: guestInterests,
                country: guestCountry,
                iconPath: Icons.person_outline_rounded,
                onTap: () => setState(() => _isGuestSelected = true),
              ),
              const SizedBox(height: 16),
              _AccountCard(
                title: 'Original Account',
                email: 'Cloud Account',
                isSelected: !_isGuestSelected,
                interests: accountInterests,
                country: accountCountry,
                iconPath: Icons.cloud_done_outlined,
                onTap: () => setState(() => _isGuestSelected = false),
              ),

              const SizedBox(height: 48),

              // Action Buttons
              GestureDetector(
                onTap: () {
                  ref.read(authNotifierProvider.notifier).resolveConflict(_isGuestSelected);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryColor, Color(0xFF4955B3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue with Selection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  List<String> _safeList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return [];
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.title,
    required this.email,
    required this.isSelected,
    required this.interests,
    required this.country,
    required this.iconPath,
    required this.onTap,
  });

  final String title;
  final String email;
  final bool isSelected;
  final List<String> interests;
  final String? country;
  final IconData iconPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6C63FF);
    const surfaceColor = Color(0xFF161B2E);
    const onSurfaceVariant = Color(0xFF8890B5);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.2 : 0.1),
              blurRadius: isSelected ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Icon/Image
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(iconPath, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: primaryColor, size: 24),
                    ],
                  ),
                  Text(
                    email,
                    style: const TextStyle(
                      color: onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Tags Row
                  Row(
                    children: [
                      // Country Tag
                      if (country != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(NewsCategory.getCountryEmoji(country!)),
                              const SizedBox(width: 4),
                              Text(
                                country!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      // Interests Preview
                      Text(
                        interests.isNotEmpty 
                          ? '${interests.length} Categories'
                          : 'No Categories',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: interests.take(3).map((catName) {
                         final cat = NewsCategory.values.firstWhere((c) => c.name == catName, orElse: () => NewsCategory.world);
                         return Text(
                           cat.emoji,
                           style: const TextStyle(fontSize: 14),
                         );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
