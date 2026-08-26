import 'package:flutter_test/flutter_test.dart';
import 'package:anhpt/core/duration_parser.dart';

void main() {
  test('parses supported durations', () {
    expect(DurationParser.parse('40s'), const Duration(seconds: 40));
    expect(DurationParser.parse('3m'), const Duration(minutes: 3));
    expect(DurationParser.parse('1m30s'), const Duration(seconds: 90));
    expect(
      DurationParser.parse('1h2m3s'),
      const Duration(hours: 1, minutes: 2, seconds: 3),
    );
  });

  test('rejects unitless duration', () {
    expect(() => DurationParser.parse('40'), throwsFormatException);
  });
}
