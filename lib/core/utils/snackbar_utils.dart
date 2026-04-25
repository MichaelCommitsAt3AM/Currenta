import 'package:flutter/material.dart';

class AppSnackbar {
  AppSnackbar._();

  /// Global key for accessing the ScaffoldMessenger without BuildContext.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFF6C63FF),
      icon: Icons.check_circle_outline_rounded,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: Colors.redAccent.shade700,
      icon: Icons.error_outline_rounded,
    );
  }

  static void showOfflineWarning({required VoidCallback onDismissed}) {
    _show(
      null,
      message: 'No internet connection',
      backgroundColor: Colors.amber.shade800,
      icon: Icons.wifi_off_rounded,
      duration: const Duration(days: 365), // Persistent
      isDismissible: true,
      onDismissed: onDismissed,
    );
  }

  static void showBackOnline() {
    _show(
      null,
      message: 'Back online!',
      backgroundColor: const Color(0xFF00C853),
      icon: Icons.wifi_rounded,
      duration: const Duration(seconds: 2),
    );
  }

  static void _show(
    BuildContext? context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 4),
    bool isDismissible = false,
    VoidCallback? onDismissed,
  }) {
    final state = context != null
        ? ScaffoldMessenger.of(context)
        : messengerKey.currentState;

    if (state == null) return;

    state.hideCurrentSnackBar();
    state.showSnackBar(
      SnackBar(
        content: isDismissible
            ? Dismissible(
                key: const Key('offline_snackbar'),
                direction: DismissDirection.startToEnd,
                onDismissed: (_) {
                  state.hideCurrentSnackBar();
                  onDismissed?.call();
                },
                child: _SnackBarContent(message: message, icon: icon),
              )
            : _SnackBarContent(message: message, icon: icon),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: duration,
        elevation: 4,
      ),
    );
  }
}

class _SnackBarContent extends StatelessWidget {
  final String message;
  final IconData icon;

  const _SnackBarContent({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }
}
