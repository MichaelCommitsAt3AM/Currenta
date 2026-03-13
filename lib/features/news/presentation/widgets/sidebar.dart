// lib/features/news/presentation/widgets/sidebar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_notifier.dart';
import '../screens/settings_screen.dart';

class Sidebar extends ConsumerWidget {
  final Color catColor;

  const Sidebar({
    super.key,
    required this.catColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final size = MediaQuery.sizeOf(context);
    
    // Calculate themed background color derived from article's category
    final sidebarBg = Color.lerp(const Color(0xFF0A0C14), catColor, 0.15)!;
    final accentColor = catColor;

    return Drawer(
      backgroundColor: Colors.transparent,
      width: size.width * 0.8,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              sidebarBg,
              const Color(0xFF0A0C14),
            ],
          ),
          border: Border(
            right: BorderSide(
              color: accentColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Branding Section ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/icons/app_logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Currenta',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Header Section ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: authState.avatarUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Image.network(
                                  authState.avatarUrl!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.person_outline_rounded,
                                    size: 32,
                                    color: accentColor,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.person_outline_rounded,
                                size: 32,
                                color: accentColor,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      authState.isAuthenticated 
                          ? 'Hi ${authState.displayName ?? 'there'},' 
                          : 'Welcome back',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      authState.isAuthenticated 
                          ? 'Signed in as member' 
                          : 'Your Daily News Pulse',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(color: Colors.white.withValues(alpha: 0.05), indent: 24, endIndent: 24),
              const SizedBox(height: 16),

              // ── Menu Items ─────────────────────────────────────────────

              const Spacer(),

              // ── Bottom Section ─────────────────────────────────────────
              Divider(color: Colors.white.withValues(alpha: 0.05), indent: 24, endIndent: 24),
              _SidebarTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                color: Colors.white.withValues(alpha: 0.7),
                onTap: () {
                  Navigator.pop(context); // Close drawer first
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              
              
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'v1.2.0 • Premium',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}
