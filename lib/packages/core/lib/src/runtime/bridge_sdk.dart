import 'dart:convert';

// ============================================================
// BRIDGE SDK — JavaScript injected into application-owned pages
// ============================================================
//
// The template below is executed inside the WebView after the page has
// finished loading. It is intentionally self-contained so that
// `test/js/bridge_sdk.test.mjs` can execute the exact same source in a Node VM.
//
// Security properties implemented here (see docs/SECURITY.md):
//  * The SDK is installed only in the top-level frame (iframes get nothing).
//  * Every message carries the per-page SESSION token; the native side rejects
//    messages without a valid token.
//  * Response/event payloads from native are parsed defensively.
//
// Do not use three consecutive single quotes inside the template: it is a Dart
// raw string delimited by triple single quotes.

/// Placeholder replaced by [buildBridgeSdk].
const String kSessionTokenPlaceholder = '__SM_SESSION_TOKEN__';

/// Returns the SDK source with [sessionToken] embedded as a JSON string literal.
String buildBridgeSdk(String sessionToken) {
  assert(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(sessionToken));
  return kBridgeSdkTemplate.replaceFirst(
    kSessionTokenPlaceholder,
    jsonEncode(sessionToken),
  );
}

const String kBridgeSdkTemplate = r'''
(function () {
  'use strict';

  // Only the top-level document gets the SDK. Iframes have no trusted context.
  if (window.top !== window.self) { return; }
  if (window.__NativeBridgeInitialized) { return; }
  window.__NativeBridgeInitialized = true;

  var SESSION_TOKEN = __SM_SESSION_TOKEN__;
  var DEFAULT_TIMEOUT_MS = 30000;

  var pending = Object.create(null);
  var eventListeners = Object.create(null);
  var requestCount = 0;

  function generateId() {
    var bytes = new Uint8Array(16);
    crypto.getRandomValues(bytes);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    var hex = Array.prototype.map.call(bytes, function (b) {
      return ('0' + b.toString(16)).slice(-2);
    }).join('');
    return hex.slice(0, 8) + '-' + hex.slice(8, 12) + '-' + hex.slice(12, 16) +
      '-' + hex.slice(16, 20) + '-' + hex.slice(20);
  }

  function postToNative(payload) {
    window.flutterBridge.postMessage(JSON.stringify(payload));
  }

  function parsePayload(payload) {
    return typeof payload === 'string' ? JSON.parse(payload) : payload;
  }

  function validNumber(value, fallback) {
    return typeof value === 'number' && isFinite(value) ? value : fallback;
  }

  var Native = {
    call: function (options) {
      options = options || {};
      if (typeof options.plugin !== 'string' || typeof options.method !== 'string') {
        return Promise.reject({
          code: 'INVALID_ARGS',
          message: 'plugin and method must be strings',
          retryable: false
        });
      }
      var plugin = options.plugin;
      var method = options.method;
      var args = options.args || {};
      var version = options.version || '1.0.0';
      var timeout = validNumber(options.timeout, DEFAULT_TIMEOUT_MS);

      return new Promise(function (resolve, reject) {
        var id = generateId();
        var timer = null;

        function settle(fn) {
          return function (value) {
            if (timer) { clearTimeout(timer); }
            delete pending[id];
            fn(value);
          };
        }

        pending[id] = { resolve: settle(resolve), reject: settle(reject) };

        if (timeout > 0) {
          timer = setTimeout(function () {
            if (pending[id]) {
              delete pending[id];
              reject({
                code: 'TIMEOUT',
                message: 'Request timed out after ' + timeout + 'ms',
                requestId: id,
                retryable: true
              });
            }
          }, timeout);
        }

        try {
          postToNative({
            requestId: id,
            token: SESSION_TOKEN,
            plugin: plugin,
            version: version,
            method: method,
            args: args,
            timestamp: new Date().toISOString(),
            metadata: { headers: {} }
          });
          requestCount++;
        } catch (e) {
          if (timer) { clearTimeout(timer); }
          delete pending[id];
          reject({
            code: 'EXECUTION_ERROR',
            message: 'Bridge unavailable',
            requestId: id,
            retryable: false
          });
        }
      });
    },

    batch: function (requests, options) {
      options = options || {};
      if (!Array.isArray(requests)) {
        return Promise.reject({
          code: 'INVALID_ARGS',
          message: 'requests must be an array',
          retryable: false
        });
      }
      var batchId = generateId();
      var timeout = validNumber(options.timeout, DEFAULT_TIMEOUT_MS);

      var mappedRequests = requests.map(function (r) {
        return {
          requestId: generateId(),
          plugin: r && r.plugin,
          method: r && r.method,
          args: (r && r.args) || {},
          version: (r && r.version) || '1.0.0',
          timestamp: new Date().toISOString(),
          metadata: { headers: {} }
        };
      });

      return new Promise(function (resolve, reject) {
        var timer = null;

        function settle(fn) {
          return function (value) {
            if (timer) { clearTimeout(timer); }
            delete pending[batchId];
            fn(value);
          };
        }

        pending[batchId] = { resolve: settle(resolve), reject: settle(reject) };

        if (timeout > 0) {
          timer = setTimeout(function () {
            if (pending[batchId]) {
              delete pending[batchId];
              reject({
                code: 'TIMEOUT',
                message: 'Batch timed out after ' + timeout + 'ms',
                requestId: batchId,
                retryable: true
              });
            }
          }, timeout);
        }

        try {
          postToNative({
            type: 'batch',
            token: SESSION_TOKEN,
            batchId: batchId,
            requests: mappedRequests,
            options: {
              parallel: options.parallel !== false,
              stopOnError: options.stopOnError === true,
              timeoutMs: timeout > 0 ? timeout : null
            }
          });
        } catch (e) {
          if (timer) { clearTimeout(timer); }
          delete pending[batchId];
          reject({
            code: 'EXECUTION_ERROR',
            message: 'Bridge unavailable',
            requestId: batchId,
            retryable: false
          });
        }
      });
    },

    on: function (event, callback) {
      if (typeof event !== 'string' || typeof callback !== 'function') {
        throw new TypeError('on(event, callback) requires a string and a function');
      }
      if (!eventListeners[event]) { eventListeners[event] = []; }
      eventListeners[event].push(callback);
      var self = this;
      return function () { self.off(event, callback); };
    },

    off: function (event, callback) {
      if (!eventListeners[event]) { return; }
      eventListeners[event] = eventListeners[event].filter(function (cb) {
        return cb !== callback;
      });
    },

    info: function () {
      return {
        initialized: true,
        pendingRequests: Object.keys(pending).length,
        totalRequests: requestCount,
        protocolVersion: 1,
        version: '1.0.0'
      };
    }
  };

  // ============================================================
  // RESPONSE / EVENT ENTRY POINTS (called by native code)
  // ============================================================

  window.__resolveCall = function (requestId, payload) {
    var entry = pending[requestId];
    if (!entry) {
      console.warn('[NativeBridge] No pending request for', requestId);
      return;
    }
    var response = parsePayload(payload) || {};
    if (response.success) {
      entry.resolve(response.data);
    } else {
      var error = response.error || { code: 'UNKNOWN', message: 'Malformed response' };
      entry.reject(Object.assign({}, error, { requestId: requestId }));
    }
  };

  window.__resolveBatch = function (batchId, payload) {
    var entry = pending[batchId];
    if (!entry) { return; }
    var response = parsePayload(payload) || {};
    if (response.error) {
      entry.reject(Object.assign({}, response.error, { requestId: batchId }));
    } else {
      entry.resolve(response.results || []);
    }
  };

  window.__emitEvent = function (event, payload) {
    var data;
    try {
      data = parsePayload(payload);
    } catch (e) {
      console.error('[NativeBridge] Malformed event payload for', event);
      return;
    }
    var listeners = (eventListeners[event] || []).slice();
    listeners.forEach(function (cb) {
      try {
        cb(data);
      } catch (e) {
        console.error('[NativeBridge] Event listener error:', e);
      }
    });
  };

  window.__bridgeDebug = {
    getStats: function () {
      return {
        pending: Object.keys(pending).length,
        total: requestCount,
        listeners: Object.keys(eventListeners)
      };
    }
  };

  window.Native = Native;

  // Tell native that this page session is ready. The token proves the message
  // comes from this page instance.
  if (window.__bridgeInternal) {
    window.__bridgeInternal.postMessage(JSON.stringify({
      type: 'bridge_ready',
      token: SESSION_TOKEN
    }));
  }

  console.log('[NativeBridge] SDK initialized');
})();
''';
