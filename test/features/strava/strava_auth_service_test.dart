import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ridecontroller/features/strava/strava_auth_service.dart';
import 'package:ridecontroller/features/strava/strava_config.dart';
import 'package:ridecontroller/features/strava/strava_token_storage.dart';

void main() {
  late DateTime now;
  late StravaTokenStorage storage;
  late List<http.Request> tokenRequests;
  late StravaAuthService auth;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    now = DateTime(2026, 11, 8, 10);
    storage = StravaTokenStorage(clock: () => now);
    await storage.saveCredentials('12345', 'secret');
    tokenRequests = [];
    final client = MockClient((request) async {
      tokenRequests.add(request);
      return http.Response(
        jsonEncode({
          'access_token': 'access',
          'refresh_token': 'refresh',
          'expires_at': 1900000000,
          'athlete': {'id': 1, 'firstname': 'Didier', 'lastname': 'G'},
        }),
        200,
      );
    });
    auth = StravaAuthService(storage: storage, httpClient: client);
  });

  Uri callback(Map<String, String> params) =>
      Uri.parse(StravaConfig.callbackUrl).replace(queryParameters: params);

  test('asks only for the public profile and activity upload', () async {
    final url = await auth.buildAuthorizationUrl();
    expect(url.queryParameters['scope'], 'read,activity:write');
  });

  test('each authorization carries a new random state', () async {
    final first =
        (await auth.buildAuthorizationUrl()).queryParameters['state']!;
    final second =
        (await auth.buildAuthorizationUrl()).queryParameters['state']!;
    expect(first.length, greaterThanOrEqualTo(40));
    expect(second, isNot(first));
    expect(await storage.readPendingOAuthState(), second);
  });

  test('the callback of our authorization is accepted once', () async {
    final state =
        (await auth.buildAuthorizationUrl()).queryParameters['state']!;
    final uri = callback(
        {'state': state, 'code': 'abc', 'scope': 'read,activity:write'});

    expect(await auth.handleCallback(uri), isTrue);
    expect(tokenRequests.single.bodyFields['code'], 'abc');
    expect((await storage.getTokens())!.accessToken, 'access');

    // Replaying the same link must not be accepted again.
    await expectLater(
        auth.handleCallback(uri), throwsA(isA<StravaAuthException>()));
    expect(tokenRequests, hasLength(1));
  });

  test('a callback forged elsewhere is rejected without using its code',
      () async {
    await auth.buildAuthorizationUrl();
    for (final params in [
      {'code': 'attacker'}, // no state
      {'code': 'attacker', 'state': 'guessed'}, // wrong state
    ]) {
      await expectLater(
        auth.handleCallback(callback(params)),
        throwsA(isA<StravaAuthException>()),
      );
    }
    expect(tokenRequests, isEmpty);
    expect(await storage.getTokens(), isNull);
  });

  test('a callback without any authorization in progress is rejected',
      () async {
    await expectLater(
      auth.handleCallback(callback({'code': 'abc', 'state': 'anything'})),
      throwsA(isA<StravaAuthException>()),
    );
    expect(tokenRequests, isEmpty);
  });

  test('an authorization older than 15 minutes is no longer accepted',
      () async {
    final state =
        (await auth.buildAuthorizationUrl()).queryParameters['state']!;
    now = now.add(const Duration(minutes: 16));
    await expectLater(
      auth.handleCallback(callback({'state': state, 'code': 'abc'})),
      throwsA(isA<StravaAuthException>()),
    );
    expect(tokenRequests, isEmpty);
  });

  test('a refusal on Strava is reported and ends the authorization', () async {
    final state =
        (await auth.buildAuthorizationUrl()).queryParameters['state']!;
    await expectLater(
      auth.handleCallback(callback({'state': state, 'error': 'access_denied'})),
      throwsA(isA<StravaAuthException>()),
    );
    expect(await storage.readPendingOAuthState(), isNull);
    expect(tokenRequests, isEmpty);
  });
}
