// Core
import 'unit/core/message_protocol_test.dart' as protocol_test;
import 'unit/core/message_bridge_test.dart' as bridge_test;
import 'unit/core/app_context_test.dart' as context_test;
import 'unit/core/plugin_error_handler_test.dart' as error_handler_test;

// Middleware
import 'unit/middleware/error_recovery_test.dart' as retry_test;
import 'unit/middleware/circuit_breaker_test.dart' as circuit_test;

// Engine
import 'unit/engine/plugin_registry_test.dart' as registry_test;
import 'unit/engine/plugin_manager_test.dart' as manager_test;
import 'unit/engine/lazy_plugin_loader_test.dart' as lazy_test;
import 'unit/engine/plugin_versioning_test.dart' as versioning_test;

// Security
import 'unit/security/rate_limiter_test.dart' as rate_test;
import 'unit/security/execution_guard_test.dart' as guard_test;

// Performance
import 'unit/performance/cache_manager_test.dart' as cache_test;

// Plugins
import 'plugins/encryption_plugin_test.dart' as encryption_test;
import 'plugins/storage_plugin_test.dart' as storage_test;
import 'plugins/all_plugins_basic_test.dart' as all_basic_test;
import 'plugins/event_plugins_test.dart' as event_test;
import 'plugins/security_plugins_test.dart' as security_test;
import 'plugins/websocket_plugin_test.dart' as ws_test;
import 'plugins/background_task_plugin_test.dart' as bg_test;
import 'plugins/dialog_plugin_test.dart' as dialog_test;
import 'plugins/app_update_plugin_test.dart' as update_test;
import 'plugins/cookie_manager_plugin_test.dart' as cookie_test;
import 'plugins/cache_control_plugin_test.dart' as cache_control_test;
import 'plugins/push_notification_plugin_test.dart' as push_test;

// Integration
import 'integration/bridge_integration_test.dart' as bridge_integration;
import 'integration/lazy_loading_integration_test.dart' as lazy_integration;
import 'unit/security/security_audit_test.dart' as security_audit_test;
import 'unit/performance/performance_audit_test.dart' as perf_audit_test;

void main() {
  // Core
  protocol_test.main();
  bridge_test.main();
  context_test.main();
  error_handler_test.main();

  // Middleware
  retry_test.main();
  circuit_test.main();

  // Engine
  registry_test.main();
  manager_test.main();
  lazy_test.main();
  versioning_test.main();

  // Security
  rate_test.main();
  guard_test.main();

  // Performance
  cache_test.main();

  // Plugins
  encryption_test.main();
  storage_test.main();
  all_basic_test.main();
  event_test.main();
  security_test.main();
  ws_test.main();
  bg_test.main();
  dialog_test.main();
  update_test.main();
  cookie_test.main();
  cache_control_test.main();
  push_test.main();

  // Integration
  bridge_integration.main();
  lazy_integration.main();
  // ── Faz 19 tests ──
  security_audit_test.main();
  perf_audit_test.main();
}
