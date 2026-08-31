import 'package:flutter/material.dart';

String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;

  final totalSeconds =
      d.inMilliseconds <= 0 ? 0 : ((d.inMilliseconds - 1) ~/ 1000) + 1;

  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;

  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  return '$m:${s.toString().padLeft(2, '0')}';
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}
