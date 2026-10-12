import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/security/lib/security.dart';

/// Provider that counts calls, so caching behaviour can be asserted.
class CountingProvider implements PermissionProvider {
  final Map<String, PermissionStatus> grants;
  int checks = 0;
  int requests = 0;

  CountingProvider(this.grants);

  @override
  Future<PermissionStatus> checkPermission(String permission) async {
    checks++;
    return grants[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> requestPermission(String permission) async {
    requests++;
    return grants[permission] ?? PermissionStatus.denied;
  }
}

void main() {
  group('PermissionManager', () {
    test('denies everything when no provider is set', () async {
      final manager = PermissionManager();

      expect(manager.hasProvider, false);
      expect(await manager.check('camera'), false);
      expect(await manager.request('camera'), false);
      expect(await manager.checkStatus('camera'), PermissionStatus.denied);
      expect(await manager.requestStatus('camera'), PermissionStatus.denied);
      expect(manager.currentStatus, isEmpty);
    });

    test('check and request report granted only when granted', () async {
      final manager = PermissionManager()
        ..setProvider(const StaticPermissionProvider(grants: {
          'camera': PermissionStatus.granted,
          'mic': PermissionStatus.permanentlyDenied,
        }));

      expect(manager.hasProvider, true);
      expect(await manager.check('camera'), true);
      expect(await manager.request('camera'), true);
      expect(await manager.check('mic'), false);
      expect(await manager.request('mic'), false);
      expect(
          await manager.checkStatus('mic'), PermissionStatus.permanentlyDenied);
    });

    test('unknown permissions use the provider default status', () async {
      final manager = PermissionManager()
        ..setProvider(const StaticPermissionProvider(
          grants: {},
          defaultStatus: PermissionStatus.notDetermined,
        ));

      expect(await manager.checkStatus('gps'), PermissionStatus.notDetermined);
      expect(
        await manager.requestStatus('gps'),
        PermissionStatus.notDetermined,
      );
    });

    test('caches checked statuses until invalidated', () async {
      final provider = CountingProvider({'camera': PermissionStatus.granted});
      final manager = PermissionManager()..setProvider(provider);

      await manager.checkStatus('camera');
      await manager.checkStatus('camera');
      expect(provider.checks, 1);
      expect(manager.currentStatus['camera'], PermissionStatus.granted);

      manager.invalidateCache('camera');
      expect(manager.currentStatus, isEmpty);
      await manager.checkStatus('camera');
      expect(provider.checks, 2);

      manager.invalidateCache();
      expect(manager.currentStatus, isEmpty);
    });

    test('expired cache entries are re-fetched from the provider', () async {
      final provider = CountingProvider({'camera': PermissionStatus.granted});
      final manager = PermissionManager(cacheTtl: Duration.zero)
        ..setProvider(provider);

      await manager.checkStatus('camera');
      await manager.checkStatus('camera');
      expect(provider.checks, 2);
    });

    test('requestStatus refreshes the cached value', () async {
      final provider = CountingProvider({});
      final manager = PermissionManager()..setProvider(provider);

      expect(await manager.checkStatus('mic'), PermissionStatus.denied);
      provider.grants['mic'] = PermissionStatus.granted;
      expect(await manager.requestStatus('mic'), PermissionStatus.granted);
      expect(provider.requests, 1);
      expect(manager.currentStatus['mic'], PermissionStatus.granted);
    });

    test('setProvider clears the existing cache', () async {
      final manager = PermissionManager()
        ..setProvider(const StaticPermissionProvider(
          grants: {'camera': PermissionStatus.granted},
        ));
      await manager.checkStatus('camera');
      expect(manager.currentStatus, isNotEmpty);

      manager.setProvider(const StaticPermissionProvider(grants: {}));
      expect(manager.currentStatus, isEmpty);
    });

    test('checkAll and batch helpers return one entry per permission',
        () async {
      final manager = PermissionManager()
        ..setProvider(const StaticPermissionProvider(grants: {
          'camera': PermissionStatus.granted,
          'location': PermissionStatus.pending,
        }));

      final bools = await manager.checkAll(['camera', 'location']);
      expect(bools, {'camera': true, 'location': false});

      final checked = await manager.checkManyStatuses(['camera', 'location']);
      expect(checked['location'], PermissionStatus.pending);

      final requested = await manager.requestManyStatuses(['camera', 'mic']);
      expect(requested['camera'], PermissionStatus.granted);
      expect(requested['mic'], PermissionStatus.denied);
    });

    test('checkPlugin passes when no policy exists', () async {
      final manager = PermissionManager()
        ..setProvider(const StaticPermissionProvider(grants: {}));

      expect(await manager.checkPlugin('unknownPlugin'), true);
    });

    test('checkPlugin requires every required permission', () async {
      final manager = PermissionManager()
        ..setProvider(const StaticPermissionProvider(grants: {
          'camera': PermissionStatus.granted,
          'microphone': PermissionStatus.denied,
        }))
        ..addPolicy(
          'recorder',
          const PermissionPolicy(
            required: ['camera', 'microphone'],
            optional: ['storage'],
          ),
        );

      expect(await manager.checkPlugin('recorder'), false);

      manager.setProvider(const StaticPermissionProvider(grants: {
        'camera': PermissionStatus.granted,
        'microphone': PermissionStatus.granted,
      }));
      expect(await manager.checkPlugin('recorder'), true);
    });

    test('NativePermissionProvider returns fallback for unmapped permissions',
        () async {
      const provider = NativePermissionProvider(
        fallbackStatus: PermissionStatus.notDetermined,
      );

      expect(await provider.checkPermission('unknownThing'),
          PermissionStatus.notDetermined);
      expect(await provider.requestPermission('unknownThing'),
          PermissionStatus.notDetermined);
    });

    test('NativePermissionProvider default fallback is denied', () async {
      const provider = NativePermissionProvider();

      expect(await provider.checkPermission('nope'), PermissionStatus.denied);
    });
  });

  group('PermissionPolicy', () {
    test('fromJson parses lists and defaults missing optional', () {
      final policy = PermissionPolicy.fromJson({
        'required': ['camera'],
      });

      expect(policy.required, ['camera']);
      expect(policy.optional, isEmpty);
    });

    test('fromJson handles missing required list', () {
      final policy = PermissionPolicy.fromJson({});

      expect(policy.required, isEmpty);
      expect(policy.optional, isEmpty);
    });

    test('toJson round-trips through fromJson', () {
      const policy = PermissionPolicy(
        required: ['camera'],
        optional: ['storage'],
      );

      final restored = PermissionPolicy.fromJson(policy.toJson());
      expect(restored.required, policy.required);
      expect(restored.optional, policy.optional);
    });
  });
}
