import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridecontroller/features/illustration/gemini_key_storage.dart';
import 'package:ridecontroller/features/illustration/illustration_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a key stored in clear by older versions moves to secure storage',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues(
        {IllustrationPrefsKeys.legacyGeminiApiKey: 'AIza-test'});

    expect(await GeminiKeyStorage().read(), 'AIza-test');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(IllustrationPrefsKeys.legacyGeminiApiKey), isNull,
        reason: 'no copy left in plain preferences');
    expect(await const FlutterSecureStorage().read(key: 'gemini_api_key'),
        'AIza-test');
  });

  test('a new key is written to secure storage only', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    await GeminiKeyStorage().write('AIza-new');

    expect(await GeminiKeyStorage().read(), 'AIza-new');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
