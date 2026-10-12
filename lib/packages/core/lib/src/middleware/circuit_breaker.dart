import 'dart:async';

import '../utils/logger.dart';

enum CircuitState {
  closed, // عادی — درخواست‌ها رد می‌شن
  open, // خطا زیاد — همه درخواست‌ها block
  halfOpen, // یه درخواست تست — اگه ok شد، بسته بشه
}

class CircuitBreakerConfig {
  final int failureThreshold;
  final Duration resetTimeout;
  final int halfOpenMaxAttempts;

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
    this.halfOpenMaxAttempts = 1,
  });
}

class CircuitBreaker {
  final String name;
  final CircuitBreakerConfig config;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _halfOpenAttempts = 0;
  DateTime? _lastFailureTime;
  int _successCount = 0;
  int _totalCalls = 0;

  CircuitBreaker({
    required this.name,
    this.config = const CircuitBreakerConfig(),
  });

  CircuitState get state {
    if (_state == CircuitState.open) {
      final elapsed = DateTime.now().difference(_lastFailureTime!);
      if (elapsed >= config.resetTimeout) {
        _state = CircuitState.halfOpen;
        _halfOpenAttempts = 0;
        BridgeLogger.info(
          'CircuitBreaker',
          '[$name] Transitioning to half-open',
        );
      }
    }
    return _state;
  }

  bool get isAllowed {
    final currentState = state;

    switch (currentState) {
      case CircuitState.closed:
        return true;
      case CircuitState.open:
        return false;
      case CircuitState.halfOpen:
        return _halfOpenAttempts < config.halfOpenMaxAttempts;
    }
  }

  Future<T> execute<T>(Future<T> Function() action) async {
    if (!isAllowed) {
      final retryAfter =
          _lastFailureTime!.add(config.resetTimeout).difference(DateTime.now());

      throw CircuitBreakerOpenException(
        name: name,
        retryAfterMs: retryAfter.inMilliseconds.clamp(0, 60000),
      );
    }

    _totalCalls++;

    if (state == CircuitState.halfOpen) {
      _halfOpenAttempts++;
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    _successCount++;

    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.closed;
      _failureCount = 0;
      BridgeLogger.info(
        'CircuitBreaker',
        '[$name] Circuit closed (recovered)',
      );
    } else {
      // Reset failure count on success in closed state
      if (_failureCount > 0) {
        _failureCount = (_failureCount - 1).clamp(0, config.failureThreshold);
      }
    }
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.open;
      BridgeLogger.warn(
        'CircuitBreaker',
        '[$name] Circuit re-opened (half-open test failed)',
      );
      return;
    }

    if (_failureCount >= config.failureThreshold) {
      _state = CircuitState.open;
      BridgeLogger.warn(
        'CircuitBreaker',
        '[$name] Circuit opened after $_failureCount failures',
      );
    }
  }

  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _halfOpenAttempts = 0;
    _lastFailureTime = null;
  }

  Map<String, dynamic> get stats => {
        'name': name,
        'state': _state.name,
        'failureCount': _failureCount,
        'successCount': _successCount,
        'totalCalls': _totalCalls,
        'failureThreshold': config.failureThreshold,
        'resetTimeoutMs': config.resetTimeout.inMilliseconds,
      };
}

class CircuitBreakerOpenException implements Exception {
  final String name;
  final int retryAfterMs;

  const CircuitBreakerOpenException({
    required this.name,
    required this.retryAfterMs,
  });

  @override
  String toString() =>
      'CircuitBreaker [$name] is open. Retry after ${retryAfterMs}ms';
}

/// Manager for multiple circuit breakers (per plugin)
class CircuitBreakerRegistry {
  final CircuitBreakerConfig defaultConfig;
  final Map<String, CircuitBreaker> _breakers = {};
  final Map<String, CircuitBreakerConfig> _configs = {};

  CircuitBreakerRegistry({
    this.defaultConfig = const CircuitBreakerConfig(),
  });

  void setConfig(String name, CircuitBreakerConfig config) {
    _configs[name] = config;
    if (_breakers.containsKey(name)) {
      _breakers[name] = CircuitBreaker(name: name, config: config);
    }
  }

  CircuitBreaker get(String name) {
    return _breakers.putIfAbsent(
      name,
      () => CircuitBreaker(
        name: name,
        config: _configs[name] ?? defaultConfig,
      ),
    );
  }

  Future<T> execute<T>(String name, Future<T> Function() action) {
    return get(name).execute(action);
  }

  void reset(String name) => _breakers[name]?.reset();

  void resetAll() {
    for (final b in _breakers.values) {
      b.reset();
    }
  }

  Map<String, dynamic> get allStats => _breakers.map(
        (key, value) => MapEntry(key, value.stats),
      );
}
