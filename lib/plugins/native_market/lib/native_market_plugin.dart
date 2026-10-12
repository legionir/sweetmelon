import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class NativeMarketPlugin extends Plugin {
  PackageInfo? _packageInfo;

  @override
  String get name => 'nativeMarket';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Link to app stores and market pages';

  @override
  List<String> get supportedMethods => [
        'openStore',
        'openDeveloperPage',
        'openOtherApp',
        'getStoreUrl',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'openStore':
        return _openStore(args);
      case 'openDeveloperPage':
        return _openDeveloperPage(args);
      case 'openOtherApp':
        return _openOtherApp(args);
      case 'getStoreUrl':
        return _getStoreUrl(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'packageName': _packageInfo?.packageName,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _openStore(Map<String, dynamic> args) async {
    final packageName =
        args['packageName'] as String? ?? _packageInfo?.packageName ?? '';

    if (packageName.isEmpty) {
      return {'opened': false, 'reason': 'no_package_name'};
    }

    final marketUri = Uri.parse('market://details?id=$packageName');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    );

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return {'opened': true, 'via': 'market'};
      }

      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return {'opened': true, 'via': 'web'};
    } catch (e) {
      return {'opened': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _openDeveloperPage(
    Map<String, dynamic> args,
  ) async {
    final developerId = args['developerId'] as String;

    final marketUri = Uri.parse(
      'market://dev?id=$developerId',
    );
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/dev?id=$developerId',
    );

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return {'opened': true, 'via': 'market'};
      }

      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return {'opened': true, 'via': 'web'};
    } catch (e) {
      return {'opened': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _openOtherApp(
    Map<String, dynamic> args,
  ) async {
    final packageName = args['packageName'] as String;
    return _openStore({'packageName': packageName});
  }

  Map<String, dynamic> _getStoreUrl(Map<String, dynamic> args) {
    final packageName =
        args['packageName'] as String? ?? _packageInfo?.packageName ?? '';

    return {
      'playStore': 'https://play.google.com/store/apps/details?id=$packageName',
      'market': 'market://details?id=$packageName',
      'packageName': packageName,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'openDeveloperPage':
        if (args['developerId'] is! String) {
          return ValidationResult.invalid('developerId is required');
        }
        return ValidationResult.valid();
      case 'openOtherApp':
        if (args['packageName'] is! String) {
          return ValidationResult.invalid('packageName is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
