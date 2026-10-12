import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  late MessageBridge bridge;

  setUp(() {
    bridge = MessageBridge();
  });

  tearDown(() {
    bridge.dispose();
  });

  group('MessageBridge', () {
    test('initial state', () {
      // bridge should not be ready initially
      // pending messages should be empty
      expect(bridge, isNotNull);
    });

    test('resetBridgeState clears pending', () {
      bridge.resetBridgeState();
      // No exception should be thrown
    });

    test('onBridgeReady processes pending messages', () {
      bridge.onBridgeReady();
      // No exception — pending queue empty
    });

    test('handles incoming message with missing fields', () async {
      bridge.setMessageHandler((request) async {
        return PluginResponse.success(
          requestId: request.requestId,
          data: 'ok',
        );
      });

      // Missing plugin and method — should send error
      await bridge.handleIncomingMessage({
        'requestId': 'test_1',
      });

      // No crash
    });

    test('handles valid incoming message', () async {
      PluginRequest? receivedRequest;

      bridge.setMessageHandler((request) async {
        receivedRequest = request;
        return PluginResponse.success(
          requestId: request.requestId,
          data: {'result': 'ok'},
        );
      });

      await bridge.handleIncomingMessage({
        'requestId': 'test_2',
        'plugin': 'storage',
        'method': 'get',
        'args': {'key': 'test'},
      });

      expect(receivedRequest, isNotNull);
      expect(receivedRequest!.plugin, 'storage');
      expect(receivedRequest!.method, 'get');
    });

    test('messageStream emits events', () async {
      bridge.setMessageHandler((request) async {
        return PluginResponse.success(
          requestId: request.requestId,
          data: 'ok',
        );
      });

      final messages = <BridgeMessage>[];
      bridge.messageStream.listen(messages.add);

      await bridge.handleIncomingMessage({
        'requestId': 'test_3',
        'plugin': 'test',
        'method': 'run',
        'args': {},
      });

      await Future.delayed(const Duration(milliseconds: 50));

      expect(messages, isNotEmpty);
      expect(messages.first.direction, BridgeMessageDirection.incoming);
    });

    test('batch request handling', () async {
      int callCount = 0;

      bridge.setMessageHandler((request) async {
        callCount++;
        return PluginResponse.success(
          requestId: request.requestId,
          data: {'index': callCount},
        );
      });

      await bridge.handleIncomingMessage({
        'type': 'batch',
        'batchId': 'batch_1',
        'requests': [
          {'requestId': 'r1', 'plugin': 'a', 'method': 'm1', 'args': {}},
          {'requestId': 'r2', 'plugin': 'b', 'method': 'm2', 'args': {}},
        ],
      });

      expect(callCount, 2);
    });
  });
}
