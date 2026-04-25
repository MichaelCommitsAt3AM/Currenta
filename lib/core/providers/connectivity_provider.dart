import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../config/app_config.dart';
import '../utils/dio_client.dart';

part 'connectivity_provider.g.dart';

enum ConnectivityStatus { online, offline, checking }

@riverpod
class ConnectivityNotifier extends _$ConnectivityNotifier {
  late final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<void>? _networkErrorSubscription;
  Timer? _pollingTimer;
  int _retryCount = 0;
  bool _isManuallyDismissed = false;

  @override
  ConnectivityStatus build() {
    _connectivity = Connectivity();
    
    // Listen to device-level connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
    
    // Listen to network errors from Dio
    _networkErrorSubscription = DioClient.networkErrorStream.stream.listen((_) {
      if (state == ConnectivityStatus.online) {
        _startPolling();
      }
    });

    ref.onDispose(() {
      _connectivitySubscription?.cancel();
      _networkErrorSubscription?.cancel();
      _pollingTimer?.cancel();
    });

    // Initial check
    _init();

    return ConnectivityStatus.online;
  }

  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    _handleConnectivityChange(result);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      _stopPolling();
      _isManuallyDismissed = false;
      state = ConnectivityStatus.offline;
    } else {
      // We have a network interface, but we don't know if the internet works yet
      // if we were already offline or if we were checking.
      if (state == ConnectivityStatus.offline) {
        _startPolling();
      }
    }
  }

  void markAsDismissed() {
    _isManuallyDismissed = true;
  }

  bool get isManuallyDismissed => _isManuallyDismissed;

  void _startPolling() {
    if (_pollingTimer != null) return;
    
    _retryCount = 0;
    _isManuallyDismissed = false;
    _performPoll();
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _retryCount = 0;
  }

  Future<void> _performPoll() async {
    _pollingTimer?.cancel();
    
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      
      // Ping the root endpoint of the backend as a lightweight check
      final response = await dio.get(AppConfig.apiBaseUrl);
      
      if (response.statusCode == 200) {
        _stopPolling();
        state = ConnectivityStatus.online;
        return;
      }
    } catch (_) {
      // Ignore errors, we'll retry
    }

    state = ConnectivityStatus.offline;
    
    // Calculate next delay with exponential backoff + jitter
    // 2s, 4s, 8s, 16s, 32s max
    final baseDelay = pow(2, min(_retryCount, 5)).toInt() * 1000;
    final jitter = (Random().nextDouble() * 0.4 - 0.2) * baseDelay; // ±20%
    final delay = Duration(milliseconds: (baseDelay + jitter).toInt());

    _retryCount++;
    _pollingTimer = Timer(delay, _performPoll);
  }
}
