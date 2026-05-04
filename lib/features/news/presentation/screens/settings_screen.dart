import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'favorites_screen.dart';
import 'chat_history_screen.dart';
import 'personalization_screen.dart';
import 'liked_articles_screen.dart';
import 'reading_history_screen.dart';
import 'about_screen.dart';
import '../../../auth/presentation/screens/account_management_screen.dart';
import '../../../auth/application/auth_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isAnon = authState.isAnonymous;
    final userEmail = authState.email;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Profile & Security ──────────────────────────────────────────────
          _SectionHeader(title: 'Profile & Security'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.account_circle_outlined,
                title: 'Account Management',
                subtitle: isAnon
                    ? 'Guest Account - Tap to Secure Data'
                    : (userEmail ?? 'Signed in via Google'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AccountManagementScreen()),
                  );
                },
                isDestructive: false,
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Your Library ──────────────────────────────────────────────────
          _SectionHeader(title: 'Your Library'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.bookmark_outline_rounded,
                title: 'Saved Articles',
                subtitle: 'Articles you have bookmarked',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FavoritesScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54, size: 20),
              ),
              const _Divider(),
              _SettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Chat History',
                subtitle: 'Previous conversations with AI',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChatHistoryScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Insights ──────────────────────────────────────────────────────
          _SectionHeader(title: 'Insights'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.favorite_border_rounded,
                title: 'Liked Articles',
                subtitle: 'Content you have liked',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LikedArticlesScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54, size: 20),
              ),
              const _Divider(),
              _SettingsTile(
                icon: Icons.history_rounded,
                title: 'Reading History',
                subtitle: 'Articles you have read recently',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ReadingHistoryScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Preferences ───────────────────────────────────────────────────
          _SectionHeader(title: 'Preferences'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.tune_rounded,
                title: 'Personalization',
                subtitle: 'Reset or update your interests',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PersonalizationScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Support & About ───────────────────────────────────────────────
          _SectionHeader(title: 'Support & About'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                subtitle: 'Version, legal information, and more',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AboutScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 48),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.05),
      indent: 52, // Align with text start
    );
  }
}
