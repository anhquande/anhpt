import 'package:anhpt/models/media_asset.dart';
import 'package:anhpt/widgets/step_demonstration_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('thumbnail resolves the new asset when media id is replaced',
      (tester) async {
    final resolvedIds = <String>[];
    MediaAsset asset(String id) => MediaAsset(
          id: id,
          type: 'video',
          mimeType: 'video/mp4',
          fileName: '$id.mp4',
          relativePath: 'video/$id.mp4',
          sizeBytes: 1,
          createdAt: DateTime.utc(2026),
        );

    Widget app(String mediaId) => MaterialApp(
          home: Scaffold(
            body: StepDemonstrationButton(
              mediaId: mediaId,
              resolveAsset: (id) async {
                resolvedIds.add(id);
                return asset(id);
              },
              resolveUri: (id) async => Uri.file('C:/$id.mp4'),
              onReplace: () async {},
              onRemove: () async {},
            ),
          ),
        );

    await tester.pumpWidget(app('media-old'));
    await tester.pump();
    expect(resolvedIds, contains('media-old'));

    await tester.pumpWidget(app('media-new'));
    await tester.pump();
    expect(resolvedIds, contains('media-new'));
  });
}
