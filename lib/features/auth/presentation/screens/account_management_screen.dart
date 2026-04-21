// lib/features/auth/presentation/screens/account_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/providers.dart';
import '../../application/auth_notifier.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'change_password_screen.dart';
import 'welcome_screen.dart';
import '../../../../core/utils/snackbar_utils.dart';

class AccountManagementScreen extends ConsumerWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final supabase = ref.watch(supabaseClientProvider);
    final user = supabase.auth.currentSession?.user;
    final isAnon = user?.isAnonymous ?? true;
    final email = user?.email;
    final name = user?.userMetadata?['full_name'] as String?;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    
    final isGoogleOnly = user?.appMetadata['provider'] == 'google' && 
        !(user?.identities?.any((id) => id.provider == 'email') ?? false);

    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0C14),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Account Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ── User Profile Header ───────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: avatarUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              color: Color(0xFF6C63FF),
                              size: 40,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          color: Color(0xFF6C63FF),
                          size: 40,
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  isAnon ? 'Guest User' : (name ?? 'Member'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAnon ? 'Sync your data to keep it safe' : (email ?? ''),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // ── Security / Status ─────────────────────────────────────────────
          if (isAnon) ...[
            _SectionHeader(title: 'Secure Your Account'),
            _InfoCard(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'You are currently using a guest account. Your saved articles and preferences are stored locally and will be lost if you clear app data.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ),
                  _ActionTile(
                    title: 'Create an Account',
                    icon: Icons.person_add_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                  ),
                  const _Divider(),
                  _ActionTile(
                    title: 'Sign In',
                    icon: Icons.login_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            if (!isGoogleOnly) ...[
              _SectionHeader(title: 'Security'),
              _InfoCard(
                child: Column(
                  children: [
                    _ActionTile(
                      title: 'Change Password',
                      icon: Icons.lock_outline_rounded,
                      onTap: () {
                        final isGoogleUser = (user?.appMetadata['provider'] == 'google' || 
                           (user?.identities?.any((id) => id.provider == 'google') ?? false));
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangePasswordScreen(isGoogleUser: isGoogleUser),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
            _SectionHeader(title: 'Linked Accounts'),
            _InfoCard(
              child: Column(
                children: [
                  _ProviderTile(
                    providerName: 'Google',
                    icon: 'assets/icons/google.png',
                    isConnected: user?.identities?.any((id) => id.provider == 'google') ?? false,
                    onLink: () {
                      ref.read(authNotifierProvider.notifier).signInWithGoogle();
                    },
                  ),
                  const _Divider(),
                  _ProviderTile(
                    providerName: 'Email & Password',
                    icon: Icons.email_outlined,
                    isConnected: user?.identities?.any((id) => id.provider == 'email') ?? false,
                    onLink: () {
                       final isGoogleUser = (user?.appMetadata['provider'] == 'google' || 
                         (user?.identities?.any((id) => id.provider == 'google') ?? false));
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangePasswordScreen(isGoogleUser: isGoogleUser),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _SectionHeader(title: 'Account Settings'),
            _InfoCard(
              child: Column(
                children: [
                   _ActionTile(
                    title: 'Sign Out',
                    icon: Icons.logout_rounded,
                    isDestructive: true,
                    onTap: () async {
                      final confirmed = await _showConfirmDialog(
                        context,
                        title: 'Log Out',
                        content: 'Are you sure you want to sign out?',
                        confirmLabel: 'Sign Out',
                      );
                      if (confirmed == true && context.mounted) {
                        await ref.read(authNotifierProvider.notifier).signOut();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── Dangerous Area ────────────────────────────────────────────────
          _SectionHeader(title: 'Danger Zone'),
          _InfoCard(
            child: _ActionTile(
              title: 'Delete Account',
              icon: Icons.delete_forever_rounded,
              isDestructive: true,
              onTap: () async {
                 final confirmed = await _showConfirmDialog(
                        context,
                        title: 'Delete Account',
                        content: 'This action is permanent and cannot be undone. All your data will be erased.',
                        confirmLabel: 'Delete',
                        isDangerous: true,
                      );
                      if (confirmed == true && context.mounted) {
                        try {
                          await ref.read(authNotifierProvider.notifier).deleteAccount();
                          if (context.mounted) {
                            AppSnackbar.showSuccess(context, 'Account and data deleted successfully');
                            
                            // Navigate to Welcome screen and clear history (brand new user experience)
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppSnackbar.showError(context, 'Failed to delete account: $e');
                          }
                        }
                      }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161A26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? Colors.redAccent : const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(confirmLabel),
          ),
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
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3)),
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
      color: Colors.white.withValues(alpha: 0.04),
      indent: 64,
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final String providerName;
  final dynamic icon; // Can be IconData or String (asset path)
  final bool isConnected;
  final VoidCallback onLink;

  const _ProviderTile({
    required this.providerName,
    required this.icon,
    required this.isConnected,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: icon is IconData
                ? Icon(icon as IconData, color: Colors.white70, size: 22)
                : Image.asset(icon as String, width: 22, height: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isConnected ? 'Connected' : 'Not Linked',
                  style: TextStyle(
                    color: isConnected ? const Color(0xFF00C853) : Colors.white.withValues(alpha: 0.3),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!isConnected)
            TextButton(
              onPressed: onLink,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: const Color(0xFF6C63FF).withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            )
          else
            const Icon(Icons.check_circle_rounded, color: Color(0xFF00C853), size: 20),
        ],
      ),
    );
  }
}
