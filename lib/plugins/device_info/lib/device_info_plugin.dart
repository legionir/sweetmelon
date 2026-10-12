import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart' as dip;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class DeviceInfoBridgePlugin extends Plugin {
  final dip.DeviceInfoPlugin _deviceInfo = dip.DeviceInfoPlugin();

  @override
  String get name => 'deviceInfo';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Device and app info plugin';

  @override
  List<String> get supportedMethods => [
        'getDeviceInfo',
        'getAppInfo',
        'getAll',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getDeviceInfo':
        return _getDeviceInfo();
      case 'getAppInfo':
        return _getAppInfo();
      case 'getAll':
        return {
          'device': await _getDeviceInfo(),
          'app': await _getAppInfo(),
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final common = {
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'numberOfProcessors': Platform.numberOfProcessors,
      'pathSeparator': Platform.pathSeparator,
    };

    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return {
        ...common,
        'brand': info.brand,
        'manufacturer': info.manufacturer,
        'model': info.model,
        'device': info.device,
        'product': info.product,
        'hardware': info.hardware,
        'board': info.board,
        'id': info.id,
        'isPhysicalDevice': info.isPhysicalDevice,
        'supportedAbis': info.supportedAbis,
        'version': {
          'sdkInt': info.version.sdkInt,
          'release': info.version.release,
          'incremental': info.version.incremental,
          'securityPatch': info.version.securityPatch,
        },
      };
    }

    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return {
        ...common,
        'name': info.name,
        'systemName': info.systemName,
        'systemVersion': info.systemVersion,
        'model': info.model,
        'localizedModel': info.localizedModel,
        'identifierForVendor': info.identifierForVendor,
        'isPhysicalDevice': info.isPhysicalDevice,
      };
    }

    return common;
  }

  Future<Map<String, dynamic>> _getAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    return {
      'appName': info.appName,
      'packageName': info.packageName,
      'version': info.version,
      'buildNumber': info.buildNumber,
      'buildSignature': info.buildSignature,
    };
  }
}
