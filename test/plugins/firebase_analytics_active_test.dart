import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/firebase_analytics/lib/firebase_analytics_plugin.dart';

/// مجموعهٔ مسیر «فعال» پلاگین آنالیتیکس.
///
/// برخلاف تست‌های تنزل‌آرام ([firebase_analytics_calls_test.dart])، اینجا
/// Firebase core با mockهای رسمی مقداردهی اولیه می‌شود و یک platform double
/// جایگزین بک‌اند واقعی، هر رویدادی را که واقعاً به پلتفرم می‌رسد ثبت می‌کند.
/// به این ترتیب قرارداد واقعیِ پارامترها (فقط string یا number) سنجیده می‌شود.
class _RecordedEvent {
  _RecordedEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object?>? parameters;
}

class _RecordingAnalyticsPlatform extends FirebaseAnalyticsPlatform {
  final List<_RecordedEvent> events = [];

  void reset() => events.clear();

  @override
  FirebaseAnalyticsPlatform delegateFor({
    required FirebaseApp app,
    Map<String, dynamic>? webOptions,
  }) {
    return this;
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    events.add(_RecordedEvent(name, parameters));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = _RecordingAnalyticsPlatform();
  late FirebaseAnalyticsPlugin plugin;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    // پیش از هر مقداردهی پلاگین نصب می‌شود تا نمونهٔ کش‌شدهٔ
    // FirebaseAnalytics همین ضبط‌کننده را به‌عنوان بک‌اند ببیند.
    FirebaseAnalyticsPlatform.instance = platform;
  });

  setUp(() async {
    platform.reset();
    plugin = FirebaseAnalyticsPlugin();
    await plugin.initialize();
  });

  test('getInfo reports the initialized analytics backend', () async {
    final info = await plugin.onCall('getInfo', {});

    expect(info, {
      'name': 'firebaseAnalytics',
      'version': '1.0.0',
      'enabled': true,
      'initialized': true,
    });
  });

  test('logEvent delivers the mixed payload once with supported types only',
      () async {
    final result = await plugin.onCall('logEvent', {
      'name': 'checkout',
      'parameters': {
        'label': 'summer',
        'count': 3,
        'price': 9.99,
        'active': true,
        'legacy': false,
        'nested': {'a': 1},
      },
    });

    expect(result, {'logged': true, 'event': 'checkout'});

    // payload دقیقاً یک بار به پلتفرم رسیده است.
    expect(platform.events, hasLength(1));
    final event = platform.events.single;
    expect(event.name, 'checkout');
    // booleanها به نمایش رشته‌ای تبدیل شده‌اند و مقدار تودرتو به رشتهٔ
    // قابل‌حمل تبدیل می‌شود؛ هیچ نوع غیرمجازی باقی نمی‌ماند.
    expect(event.parameters, {
      'label': 'summer',
      'count': 3,
      'price': 9.99,
      'active': 'true',
      'legacy': 'false',
      'nested': '{a: 1}',
    });
    for (final value in event.parameters!.values) {
      expect(value, anyOf(isA<String>(), isA<num>()));
    }
  });

  test('commerce events marshal item values to the platform', () async {
    final items = [
      {
        'itemId': 'i-1',
        'itemName': 'Mug',
        'itemCategory': 'kitchen',
        'price': 4.5,
        'quantity': 2,
        'currency': 'USD',
      },
    ];

    final result = await plugin.onCall('logPurchase', {
      'currency': 'USD',
      'value': 9,
      'transactionId': 't-1',
      'items': items,
    });
    expect(result, {'logged': true});

    final purchase = platform.events.single;
    expect(purchase.name, 'purchase');
    expect(purchase.parameters, {
      'currency': 'USD',
      'value': 9.0,
      'transaction_id': 't-1',
      'items': [
        {
          'currency': 'USD',
          'item_category': 'kitchen',
          'item_id': 'i-1',
          'item_name': 'Mug',
          'price': 4.5,
          'quantity': 2,
        },
      ],
    });
  });

  test('logLevelEnd maps an explicit success=false to zero', () async {
    await plugin.onCall('logLevelEnd', {'levelName': 'l-1', 'success': false});

    final failed = platform.events.single;
    expect(failed.name, 'level_end');
    expect(failed.parameters, {'level_name': 'l-1', 'success': 0});
  });

  test('logLevelEnd honours boolean and string success contracts', () async {
    await plugin.onCall('logLevelEnd', {'levelName': 'l-2', 'success': true});
    await plugin
        .onCall('logLevelEnd', {'levelName': 'l-3', 'success': 'false'});
    await plugin.onCall('logLevelEnd', {'levelName': 'l-4'});

    expect(platform.events.map((e) => e.name), everyElement('level_end'));
    expect(
      platform.events.map((e) => e.parameters!['success']).toList(),
      [1, 0, 1],
    );
    expect(
      platform.events.map((e) => e.parameters!['level_name']).toList(),
      ['l-2', 'l-3', 'l-4'],
    );
  });
}
