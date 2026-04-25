import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../utils/snackbar_utils.dart';

class ConnectivityListener extends ConsumerWidget {
  const ConnectivityListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ConnectivityStatus>(
      connectivityNotifierProvider,
      (previous, next) {
        // If we transitioned to offline
        if (next == ConnectivityStatus.offline) {
          final notifier = ref.read(connectivityNotifierProvider.notifier);
          if (!notifier.isManuallyDismissed) {
            AppSnackbar.showOfflineWarning(
              onDismissed: () => notifier.markAsDismissed(),
            );
          }
        }
        
        // If we transitioned from offline to online
        if (previous == ConnectivityStatus.offline && next == ConnectivityStatus.online) {
          AppSnackbar.messengerKey.currentState?.hideCurrentSnackBar();
          AppSnackbar.showBackOnline();
        }
      },
    );

    return child;
  }
}
