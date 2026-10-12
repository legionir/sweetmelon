import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class DatabasePlugin extends Plugin {
  final Map<String, Database> _databases = {};

  @override
  String get name => 'database';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'SQLite database plugin';

  @override
  List<String> get supportedMethods => [
        'open',
        'close',
        'execute',
        'query',
        'insert',
        'update',
        'delete',
        'rawQuery',
        'rawInsert',
        'rawUpdate',
        'rawDelete',
        'batch',
        'tableExists',
        'getOpenDatabases',
        'deleteDatabase',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    for (final db in _databases.values) {
      if (db.isOpen) await db.close();
    }
    _databases.clear();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'open':
        return _open(args);
      case 'close':
        return _close(args);
      case 'execute':
        return _execute(args);
      case 'query':
        return _query(args);
      case 'insert':
        return _insert(args);
      case 'update':
        return _update(args);
      case 'delete':
        return _deleteRows(args);
      case 'rawQuery':
        return _rawQuery(args);
      case 'rawInsert':
        return _rawInsert(args);
      case 'rawUpdate':
        return _rawUpdate(args);
      case 'rawDelete':
        return _rawDelete(args);
      case 'batch':
        return _batch(args);
      case 'tableExists':
        return _tableExists(args);
      case 'getOpenDatabases':
        return {'databases': _databases.keys.toList()};
      case 'deleteDatabase':
        return _deleteDatabase(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'openDatabases': _databases.keys.toList(),
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Database> _getDb(String dbName) async {
    final db = _databases[dbName];
    if (db == null || !db.isOpen) {
      throw StateError('Database "$dbName" is not open');
    }
    return db;
  }

  Future<Map<String, dynamic>> _open(Map<String, dynamic> args) async {
    final dbName = args['name'] as String;
    final dbVersion = (args['version'] as num?)?.toInt() ?? 1;
    final createStatements = args['onCreate'] as List<dynamic>?;

    if (_databases.containsKey(dbName) && _databases[dbName]!.isOpen) {
      return {'opened': true, 'alreadyOpen': true, 'name': dbName};
    }

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'databases', '$dbName.db');

    final db = await openDatabase(
      dbPath,
      version: dbVersion,
      onCreate: (db, version) async {
        if (createStatements != null) {
          for (final stmt in createStatements) {
            if (stmt is String && stmt.trim().isNotEmpty) {
              await db.execute(stmt);
            }
          }
        }
      },
    );

    _databases[dbName] = db;
    BridgeLogger.info('Database', 'Opened: $dbName (v$dbVersion)');

    return {
      'opened': true,
      'alreadyOpen': false,
      'name': dbName,
      'path': dbPath
    };
  }

  Future<Map<String, dynamic>> _close(Map<String, dynamic> args) async {
    final dbName = args['name'] as String;
    final db = _databases.remove(dbName);

    if (db != null && db.isOpen) {
      await db.close();
      return {'closed': true, 'name': dbName};
    }

    return {'closed': false, 'reason': 'not_open'};
  }

  Future<Map<String, dynamic>> _execute(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final sql = args['sql'] as String;
    final params = _parseParams(args['params']);

    await db.execute(sql, params);
    return {'executed': true};
  }

  Future<Map<String, dynamic>> _query(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final table = args['table'] as String;
    final where = args['where'] as String?;
    final whereArgs = _parseParams(args['whereArgs']);
    final orderBy = args['orderBy'] as String?;
    final limit = (args['limit'] as num?)?.toInt();
    final offset = (args['offset'] as num?)?.toInt();
    final columns = args['columns'] != null
        ? List<String>.from(args['columns'] as List)
        : null;

    final results = await db.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return {'rows': results, 'count': results.length};
  }

  Future<Map<String, dynamic>> _insert(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final table = args['table'] as String;
    final values = Map<String, dynamic>.from(args['values'] as Map);

    final id = await db.insert(table, values);
    return {'id': id, 'inserted': true};
  }

  Future<Map<String, dynamic>> _update(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final table = args['table'] as String;
    final values = Map<String, dynamic>.from(args['values'] as Map);
    final where = args['where'] as String?;
    final whereArgs = _parseParams(args['whereArgs']);

    final count =
        await db.update(table, values, where: where, whereArgs: whereArgs);
    return {'updated': count};
  }

  Future<Map<String, dynamic>> _deleteRows(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final table = args['table'] as String;
    final where = args['where'] as String?;
    final whereArgs = _parseParams(args['whereArgs']);

    final count = await db.delete(table, where: where, whereArgs: whereArgs);
    return {'deleted': count};
  }

  Future<Map<String, dynamic>> _rawQuery(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final sql = args['sql'] as String;
    final params = _parseParams(args['params']);

    final results = await db.rawQuery(sql, params);
    return {'rows': results, 'count': results.length};
  }

  Future<Map<String, dynamic>> _rawInsert(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final sql = args['sql'] as String;
    final params = _parseParams(args['params']);

    final id = await db.rawInsert(sql, params);
    return {'id': id};
  }

  Future<Map<String, dynamic>> _rawUpdate(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final sql = args['sql'] as String;
    final params = _parseParams(args['params']);

    final count = await db.rawUpdate(sql, params);
    return {'affected': count};
  }

  Future<Map<String, dynamic>> _rawDelete(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final sql = args['sql'] as String;
    final params = _parseParams(args['params']);

    final count = await db.rawDelete(sql, params);
    return {'affected': count};
  }

  Future<Map<String, dynamic>> _batch(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final statements =
        List<Map<String, dynamic>>.from(args['statements'] as List);

    final batch = db.batch();

    for (final stmt in statements) {
      final type = stmt['type'] as String;
      final sql = stmt['sql'] as String?;
      final table = stmt['table'] as String?;
      final values = stmt['values'] as Map<String, dynamic>?;
      final where = stmt['where'] as String?;
      final whereArgs = _parseParams(stmt['whereArgs']);

      switch (type) {
        case 'execute':
          if (sql != null) batch.execute(sql);
          break;
        case 'insert':
          if (table != null && values != null) batch.insert(table, values);
          break;
        case 'update':
          if (table != null && values != null) {
            batch.update(table, values, where: where, whereArgs: whereArgs);
          }
          break;
        case 'delete':
          if (table != null) {
            batch.delete(table, where: where, whereArgs: whereArgs);
          }
          break;
        case 'rawInsert':
          if (sql != null) batch.rawInsert(sql, _parseParams(stmt['params']));
          break;
        case 'rawUpdate':
          if (sql != null) batch.rawUpdate(sql, _parseParams(stmt['params']));
          break;
        case 'rawDelete':
          if (sql != null) batch.rawDelete(sql, _parseParams(stmt['params']));
          break;
      }
    }

    final results = await batch.commit();
    return {'results': results, 'count': results.length};
  }

  Future<Map<String, dynamic>> _tableExists(Map<String, dynamic> args) async {
    final db = await _getDb(args['name'] as String);
    final table = args['table'] as String;

    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );

    return {'exists': result.isNotEmpty, 'table': table};
  }

  Future<Map<String, dynamic>> _deleteDatabase(
      Map<String, dynamic> args) async {
    final dbName = args['name'] as String;

    // close first
    final db = _databases.remove(dbName);
    if (db != null && db.isOpen) await db.close();

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'databases', '$dbName.db');

    await databaseFactory.deleteDatabase(dbPath);

    return {'deleted': true, 'name': dbName};
  }

  List<dynamic>? _parseParams(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) return raw;
    return null;
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    final needsName = [
      'open',
      'close',
      'execute',
      'query',
      'insert',
      'update',
      'delete',
      'rawQuery',
      'rawInsert',
      'rawUpdate',
      'rawDelete',
      'batch',
      'tableExists',
      'deleteDatabase',
    ];

    if (needsName.contains(method)) {
      final name = args['name'];
      if (name is! String || name.isEmpty) {
        return ValidationResult.invalid('name (database name) is required');
      }
    }

    switch (method) {
      case 'execute':
      case 'rawQuery':
      case 'rawInsert':
      case 'rawUpdate':
      case 'rawDelete':
        final sql = args['sql'];
        if (sql is! String || sql.isEmpty) {
          return ValidationResult.invalid('sql is required');
        }
        return ValidationResult.valid();

      case 'query':
      case 'delete':
        final table = args['table'];
        if (table is! String || table.isEmpty) {
          return ValidationResult.invalid('table is required');
        }
        return ValidationResult.valid();

      case 'insert':
      case 'update':
        final table = args['table'];
        if (table is! String || table.isEmpty) {
          return ValidationResult.invalid('table is required');
        }
        if (args['values'] is! Map) {
          return ValidationResult.invalid(
              'values is required and must be a map');
        }
        return ValidationResult.valid();

      case 'tableExists':
        final table = args['table'];
        if (table is! String || table.isEmpty) {
          return ValidationResult.invalid('table is required');
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
