import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../../core/providers/providers.dart';
import 'favorites_screen.dart';
import 'chat_history_screen.dart';
import 'personalization_screen.dart';
import 'liked_articles_screen.dart';
import 'reading_history_screen.dart';
import '../../../auth/presentation/screens/account_management_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isAuthenticated = authState.isAuthenticated;
    final isAnon = Supabase.instance.client.auth.currentSession?.user.isAnonymous ?? true;
    final userEmail = Supabase.instance.client.auth.currentSession?.user.email;

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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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
                    MaterialPageRoute(builder: (context) => const AccountManagementScreen()),
                  );
                },
                isDestructive: false,
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
              ),
              if (isAuthenticated) ...[
                const _Divider(),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Log Out',
                  subtitle: 'Sign out of your account',
                  isDestructive: true,
                  onTap: () => _showLogoutConfirmation(context, ref),
                ),
              ],
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
                    MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
              ),
              const _Divider(),
              _SettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Chat History',
                subtitle: 'Previous conversations with AI',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatHistoryScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
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
                    MaterialPageRoute(builder: (context) => const LikedArticlesScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
              ),
              const _Divider(),
              _SettingsTile(
                icon: Icons.history_rounded,
                title: 'Reading History',
                subtitle: 'Articles you have read recently',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReadingHistoryScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
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
                    MaterialPageRoute(builder: (context) => const PersonalizationScreen()),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
              ),
            ],
          ),
          
          const SizedBox(height: 48),

          // ── App Versions ─────────────────────────────────────────────────
          FutureBuilder<List<String>>(
            future: Future.wait([
              PackageInfo.fromPlatform().then((info) => info.version),
              // We fetch backend version from the root endpoint
              ref.read(dioClientProvider).get('/').then((res) => res.data['backend_version']?.toString() ?? 'Unknown'),
            ]),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final appVersion = snapshot.data![0];
                final backendVersion = snapshot.data![1];
                return Column(
                  children: [
                    Text(
                      'App v$appVersion • Backend v$backendVersion',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Separately Versioned Systems',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.15),
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          const SizedBox(height: 24), // Padding at bottom
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF141621),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Log Out?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to log out? You will need to sign in again to access your personalized feed and saved articles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context),
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DialogButton(
                    label: 'Log Out',
                    onTap: () async {
                      Navigator.pop(context); // Close sheet
                      await ref.read(authNotifierProvider.notifier).signOut();
                      if (context.mounted) {
                        Navigator.pop(context); // Go back after logout
                      }
                    },
                    isPrimary: true,
                    isDestructive: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;

  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary 
          ? (isDestructive ? Colors.redAccent : const Color(0xFF6C63FF))
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
