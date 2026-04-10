import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'About',
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                // ── Branding ───────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color:
                                const Color(0xFF6C63FF).withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF)
                                  .withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/icons/app_logo_new.png',
                          height: 60,
                          width: 60,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Currenta',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Modern news, simplified.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // ── Legal Section ──────────────────────────────────────────
                _AboutSectionHeader(title: 'Legal Information'),
                const SizedBox(height: 12),
                _AboutTile(
                  title: 'Privacy Policy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {
                    // TODO: Open Privacy Policy URL
                  },
                ),
                const SizedBox(height: 16),
                _AboutTile(
                  title: 'Terms of Service',
                  icon: Icons.description_outlined,
                  onTap: () {
                    // TODO: Open Terms of Service URL
                  },
                ),
                const SizedBox(height: 16),
                _AboutTile(
                  title: 'Open Source Licenses',
                  icon: Icons.code_rounded,
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Currenta',
                      applicationVersion: '1.2.0', // Fallback
                      applicationIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset('assets/icons/app_logo_new.png',
                            width: 48, height: 48),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // ── Contact Section ────────────────────────────────────────
                _AboutSectionHeader(title: 'Connect'),
                const SizedBox(height: 12),
                _AboutTile(
                  title: 'Send Feedback',
                  icon: Icons.feedback_outlined,
                  onTap: () {
                    // TODO: Open feedback email/form
                  },
                ),
                const SizedBox(height: 16),
                _AboutTile(
                  title: 'Follow us on X',
                  icon: Icons.alternate_email_rounded,
                  onTap: () {
                    // TODO: Open Social Link
                  },
                ),
              ],
            ),
          ),

          // ── App Version Footer ───────────────────────────────────────────
          // TODO: Add 'Beta' tag to version string when launching in beta
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '...';
              final buildNumber = snapshot.data?.buildNumber ?? '';

              return Container(
                padding: EdgeInsets.fromLTRB(
                    24, 24, 24, MediaQuery.paddingOf(context).bottom + 32),
                child: Opacity(
                  opacity: 0.3,
                  child: Column(
                    children: [
                      Text(
                        'CURRENTA v$version($buildNumber)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '© 2026 Currenta News. All rights reserved.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AboutSectionHeader extends StatelessWidget {
  final String title;
  const _AboutSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
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

class _AboutTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _AboutTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF6C63FF), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white12, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
