import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class ContactsPlugin extends Plugin {
  @override
  String get name => 'contacts';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Contacts read plugin';

  @override
  List<String> get requiredPermissions => ['contacts'];

  @override
  List<String> get supportedMethods => [
        'getAll',
        'getById',
        'search',
        'getCount',
        'pickContact',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getAll':
        return _getAll(args);
      case 'getById':
        return _getById(args);
      case 'search':
        return _search(args);
      case 'getCount':
        return _getCount();
      case 'pickContact':
        return _pickContact();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _getAll(Map<String, dynamic> args) async {
    final withProperties = args['withProperties'] as bool? ?? true;
    final withPhoto = args['withPhoto'] as bool? ?? false;
    final limit = (args['limit'] as num?)?.toInt();
    final offset = (args['offset'] as num?)?.toInt() ?? 0;

    final hasPermission = await FlutterContacts.requestPermission();
    if (!hasPermission) {
      return {'contacts': <dynamic>[], 'error': 'permission_denied'};
    }

    var contacts = await FlutterContacts.getContacts(
      withProperties: withProperties,
      withPhoto: withPhoto,
    );

    if (offset > 0 && offset < contacts.length) {
      contacts = contacts.sublist(offset);
    }

    if (limit != null && limit > 0 && limit < contacts.length) {
      contacts = contacts.sublist(0, limit);
    }

    return {
      'contacts': contacts.map(_contactToMap).toList(),
      'count': contacts.length,
    };
  }

  Future<Map<String, dynamic>> _getById(Map<String, dynamic> args) async {
    final id = args['id'] as String;

    final hasPermission = await FlutterContacts.requestPermission();
    if (!hasPermission) {
      return {'contact': null, 'error': 'permission_denied'};
    }

    final contact = await FlutterContacts.getContact(
      id,
      withProperties: true,
      withPhoto: false,
    );

    if (contact == null) {
      return {'contact': null, 'found': false};
    }

    return {'contact': _contactToMap(contact), 'found': true};
  }

  Future<Map<String, dynamic>> _search(Map<String, dynamic> args) async {
    final query = (args['query'] as String).toLowerCase().trim();

    final hasPermission = await FlutterContacts.requestPermission();
    if (!hasPermission) {
      return {'contacts': <dynamic>[], 'error': 'permission_denied'};
    }

    final allContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    final filtered = allContacts.where((c) {
      final displayName = c.displayName.toLowerCase();
      if (displayName.contains(query)) return true;

      for (final phone in c.phones) {
        if (phone.number.replaceAll(RegExp(r'\s+'), '').contains(query)) {
          return true;
        }
      }

      for (final email in c.emails) {
        if (email.address.toLowerCase().contains(query)) return true;
      }

      return false;
    }).toList();

    return {
      'contacts': filtered.map(_contactToMap).toList(),
      'count': filtered.length,
      'query': query,
    };
  }

  Future<Map<String, dynamic>> _getCount() async {
    final hasPermission = await FlutterContacts.requestPermission();
    if (!hasPermission) {
      return {'count': 0, 'error': 'permission_denied'};
    }

    final contacts = await FlutterContacts.getContacts();
    return {'count': contacts.length};
  }

  Future<Map<String, dynamic>> _pickContact() async {
    final contact = await FlutterContacts.openExternalPick();

    if (contact == null) {
      return {'contact': null, 'picked': false};
    }

    return {'contact': _contactToMap(contact), 'picked': true};
  }

  Map<String, dynamic> _contactToMap(Contact contact) {
    return {
      'id': contact.id,
      'displayName': contact.displayName,
      'name': {
        'first': contact.name.first,
        'last': contact.name.last,
        'middle': contact.name.middle,
        'prefix': contact.name.prefix,
        'suffix': contact.name.suffix,
        'nickname': contact.name.nickname,
      },
      'phones': contact.phones.map((p) {
        return {
          'number': p.number,
          'label': p.label.name,
          'isPrimary': p.isPrimary,
        };
      }).toList(),
      'emails': contact.emails.map((e) {
        return {
          'address': e.address,
          'label': e.label.name,
          'isPrimary': e.isPrimary,
        };
      }).toList(),
      'organizations': contact.organizations.map((o) {
        return {
          'company': o.company,
          'title': o.title,
          'department': o.department,
        };
      }).toList(),
      'addresses': contact.addresses.map((a) {
        return {
          'address': a.address,
          'label': a.label.name,
        };
      }).toList(),
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'getById':
        final id = args['id'];
        if (id is! String || id.isEmpty) {
          return ValidationResult.invalid('id is required');
        }
        return ValidationResult.valid();

      case 'search':
        final query = args['query'];
        if (query is! String || query.isEmpty) {
          return ValidationResult.invalid('query is required');
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
