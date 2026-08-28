import 'package:anhpt/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('seeds the official workout source on first load', () async {
    final store = LocalStore();

    final sources = await store.loadBucketSources();

    expect(sources, hasLength(1));
    expect(sources.single.id, LocalStore.defaultBucketSourceId);
    expect(sources.single.name, LocalStore.defaultBucketSourceName);
    expect(sources.single.catalogUrl, LocalStore.defaultBucketSourceUrl);
    expect(sources.single.enabled, isTrue);
  });

  test('adds the official source once for existing installations', () async {
    SharedPreferences.setMockInitialValues({
      'anhpt.bucketSources.v1':
          '[{"id":"custom","name":"Custom","catalogUrl":"https://example.com/bucket.json","enabled":true}]',
    });
    final store = LocalStore();

    final sources = await store.loadBucketSources();

    expect(sources, hasLength(2));
    expect(sources.first.id, LocalStore.defaultBucketSourceId);
    expect(sources.last.id, 'custom');
  });

  test('does not recreate the official source after the user removes it',
      () async {
    final store = LocalStore();
    await store.loadBucketSources();
    await store.saveBucketSources([]);

    final sources = await store.loadBucketSources();

    expect(sources, isEmpty);
  });
}
