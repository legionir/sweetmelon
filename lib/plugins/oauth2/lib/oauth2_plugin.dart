import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class OAuth2Plugin extends Plugin {
  @override
  String get name => 'oauth2';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Generic OAuth2 authentication plugin';

  @override
  List<String> get supportedMethods => [
        'authorize',
        'exchangeCode',
        'refreshToken',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'authorize':
        return _authorize(args);
      case 'exchangeCode':
        return _exchangeCode(args);
      case 'refreshToken':
        return _refreshToken(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _authorize(Map<String, dynamic> args) async {
    final authUrl = args['authUrl'] as String;
    final clientId = args['clientId'] as String;
    final redirectUri = args['redirectUri'] as String;
    final scope = args['scope'] as String? ?? '';
    final responseType = args['responseType'] as String? ?? 'code';
    final state = args['state'] as String?;
    final extraParams = args['extraParams'] as Map<String, dynamic>? ?? {};

    final params = {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': responseType,
      if (scope.isNotEmpty) 'scope': scope,
      if (state != null) 'state': state,
      ...extraParams.map((k, v) => MapEntry(k, v.toString())),
    };

    final queryString = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final fullUrl = '$authUrl?$queryString';

    BridgeLogger.info('OAuth2', 'Starting authorization: $authUrl');

    final context = AppContext().context;
    if (context == null) {
      return {'success': false, 'reason': 'no_context'};
    }

    final completer = Completer<Map<String, dynamic>>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _OAuth2WebViewPage(
          url: fullUrl,
          redirectUri: redirectUri,
          onResult: (result) {
            if (!completer.isCompleted) {
              completer.complete(result);
            }
          },
        ),
      ),
    );

    return completer.future;
  }

  Future<Map<String, dynamic>> _exchangeCode(
    Map<String, dynamic> args,
  ) async {
    final tokenUrl = args['tokenUrl'] as String;
    final code = args['code'] as String;
    final clientId = args['clientId'] as String;
    final clientSecret = args['clientSecret'] as String?;
    final redirectUri = args['redirectUri'] as String;
    final codeVerifier = args['codeVerifier'] as String?;

    try {
      final body = {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': clientId,
        'redirect_uri': redirectUri,
        if (clientSecret != null) 'client_secret': clientSecret,
        if (codeVerifier != null) 'code_verifier': codeVerifier,
      };

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'accessToken': data['access_token'],
          'refreshToken': data['refresh_token'],
          'expiresIn': data['expires_in'],
          'tokenType': data['token_type'],
          'scope': data['scope'],
          'idToken': data['id_token'],
        };
      }

      return {
        'success': false,
        'statusCode': response.statusCode,
        'error': response.body,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _refreshToken(
    Map<String, dynamic> args,
  ) async {
    final tokenUrl = args['tokenUrl'] as String;
    final refreshToken = args['refreshToken'] as String;
    final clientId = args['clientId'] as String;
    final clientSecret = args['clientSecret'] as String?;

    try {
      final body = {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
        if (clientSecret != null) 'client_secret': clientSecret,
      };

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'accessToken': data['access_token'],
          'refreshToken': data['refresh_token'] ?? refreshToken,
          'expiresIn': data['expires_in'],
        };
      }

      return {
        'success': false,
        'statusCode': response.statusCode,
        'error': response.body,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'authorize':
        for (final f in ['authUrl', 'clientId', 'redirectUri']) {
          if (args[f] is! String || (args[f] as String).isEmpty) {
            return ValidationResult.invalid('$f is required');
          }
        }
        return ValidationResult.valid();
      case 'exchangeCode':
        for (final f in ['tokenUrl', 'code', 'clientId', 'redirectUri']) {
          if (args[f] is! String) {
            return ValidationResult.invalid('$f is required');
          }
        }
        return ValidationResult.valid();
      case 'refreshToken':
        for (final f in ['tokenUrl', 'refreshToken', 'clientId']) {
          if (args[f] is! String) {
            return ValidationResult.invalid('$f is required');
          }
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}

class _OAuth2WebViewPage extends StatelessWidget {
  final String url;
  final String redirectUri;
  final void Function(Map<String, dynamic>) onResult;

  const _OAuth2WebViewPage({
    required this.url,
    required this.redirectUri,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121A2D),
        title: const Text('Sign In', style: TextStyle(fontSize: 14)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            onResult({'success': false, 'reason': 'cancelled'});
            Navigator.of(context).pop();
          },
        ),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          clearCache: true,
        ),
        onLoadStop: (controller, loadedUrl) {
          if (loadedUrl != null &&
              loadedUrl.toString().startsWith(redirectUri)) {
            final uri = Uri.parse(loadedUrl.toString());
            final code = uri.queryParameters['code'];
            final state = uri.queryParameters['state'];
            final error = uri.queryParameters['error'];

            if (error != null) {
              onResult({
                'success': false,
                'error': error,
                'errorDescription': uri.queryParameters['error_description'],
              });
            } else if (code != null) {
              onResult({
                'success': true,
                'code': code,
                'state': state,
                'redirectUrl': loadedUrl.toString(),
              });
            } else {
              // fragment response (implicit flow)
              final fragment = uri.fragment;
              final fragmentParams = Uri.splitQueryString(fragment);

              onResult({
                'success': fragmentParams.containsKey('access_token'),
                'accessToken': fragmentParams['access_token'],
                'tokenType': fragmentParams['token_type'],
                'expiresIn': fragmentParams['expires_in'],
                'state': fragmentParams['state'],
              });
            }

            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
