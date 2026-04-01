// lib/features/auth/presentation/widgets/personalization_conflict_dialog.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/providers.dart';
import '../../../news/domain/entities/news_category.dart';
import '../../application/auth_notifier.dart';

class PersonalizationConflictDialog extends ConsumerWidget {
  const PersonalizationConflictDialog({
    super.key,
    required this.guestData,
    required this.accountData,
  });

  final Map<String, dynamic> guestData;
  final Map<String, dynamic> accountData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestInterests = List<String>.from(guestData['interests'] ?? []);
    final accountInterests = List<String>.from(accountData['interests'] ?? []);
    final guestCountry = guestData['country'] as String?;
    final accountCountry = accountData['account_country'] as String? ?? accountData['country'] as String?;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: const Color(0xFF161B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.sync_problem_rounded, color: Color(0xFF6C63FF), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Personalization Conflict',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We found existing news preferences on your account. Which settings would you like to continue with?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ProfileComparisonCard(
                      title: 'Current Guest',
                      interests: guestInterests,
                      country: guestCountry,
                      accentColor: const Color(0xFF6C63FF),
                      onSelected: () => ref.read(authNotifierProvider.notifier).resolveConflict(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProfileComparisonCard(
                      title: 'Original Account',
                      interests: accountInterests,
                      country: accountCountry,
                      accentColor: Colors.white.withValues(alpha: 0.1),
                      onSelected: () => ref.read(authNotifierProvider.notifier).resolveConflict(false),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              Text(
                '* Your reading history and favorites will be merged regardless of your choice.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileComparisonCard extends StatelessWidget {
  const _ProfileComparisonCard({
    required this.title,
    required this.interests,
    required this.country,
    required this.accentColor,
    required this.onSelected,
  });

  final String title;
  final List<String> interests;
  final String? country;
  final Color accentColor;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor == const Color(0xFF6C63FF) 
                ? accentColor 
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accentColor == const Color(0xFF6C63FF) ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            if (country != null) ...[
              Row(
                children: [
                   Text(NewsCategory.getCountryEmoji(country!), style: const TextStyle(fontSize: 16)),
                   const SizedBox(width: 6),
                   Expanded(
                     child: Text(
                        NewsCategory.getCountryName(country!),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: interests.take(4).map((name) {
                final cat = NewsCategory.values.firstWhere((c) => c.name == name, orElse: () => NewsCategory.world);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cat.emoji,
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ),
            if (interests.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${interests.length - 4} more',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: accentColor == const Color(0xFF6C63FF) ? accentColor : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Keep',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
