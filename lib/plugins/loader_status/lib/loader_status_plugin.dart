import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class LoaderStatusPlugin extends Plugin {
  final LazyPluginLoader loader;

  LoaderStatusPlugin({required this.loader});

  @override
  String get name => '_loader';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Internal plugin loader status';

  @override
  List<String> get supportedMethods => [
        'getStats',
        'getStatus',
        'preload',
        'unload',
        'reload',
        'getLoadedPlugins',
        'getUnloadedPlugins',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getStats':
        return loader.stats;

      case 'getStatus':
        final pluginId = args['plugin'] as String;
        final status = loader.allStatuses[pluginId];
        if (status == null) {
          return {'plugin': pluginId, 'registered': false};
        }
        return {
          'plugin': pluginId,
          'registered': true,
          ...status.toJson(),
        };

      case 'preload':
        final plugins = List<String>.from(args['plugins'] as List);
        loader.preload(plugins);
        return {'preloading': plugins};

      case 'unload':
        final pluginId = args['plugin'] as String;
        await loader.unload(pluginId);
        return {'unloaded': pluginId};

      case 'reload':
        final pluginId = args['plugin'] as String;
        await loader.reload(pluginId);
        return {'reloaded': pluginId};

      case 'getLoadedPlugins':
        return {'plugins': loader.loadedPlugins};

      case 'getUnloadedPlugins':
        return {'plugins': loader.unloadedPlugins};

      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }
}
