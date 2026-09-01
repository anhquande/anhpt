import 'package:anhpt/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateService.compareVersions', () {
    test('compares semantic versions', () {
      expect(UpdateService.compareVersions('0.14.0', '0.13.0'), greaterThan(0));
      expect(UpdateService.compareVersions('v1.0.0', '1.0.0'), 0);
      expect(UpdateService.compareVersions('1.2.3+42', '1.2.4'), lessThan(0));
    });

    test('handles missing components', () {
      expect(UpdateService.compareVersions('1.2', '1.2.0'), 0);
      expect(UpdateService.compareVersions('2', '1.9.9'), greaterThan(0));
    });
  });
}
