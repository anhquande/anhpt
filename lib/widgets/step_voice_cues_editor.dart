import 'package:flutter/material.dart';

import '../models/workout_draft.dart';

class StepVoiceCuesEditor extends StatelessWidget {
  final StepDraft step;
  final VoidCallback changed;

  const StepVoiceCuesEditor({
    super.key,
    required this.step,
    required this.changed,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: const Icon(Icons.record_voice_over_outlined),
      title: const Text(
        'Voice Coach cues',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: const Text('Configure contextual coaching for this step'),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Announce next step'),
          subtitle: const Text(
            'Say the next step near the end when there is enough time.',
          ),
          value: step.announceNext,
          onChanged: (value) {
            step.announceNext = value;
            changed();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Get ready'),
          subtitle: const Text('Play a preparation cue before timing starts.'),
          value: step.getReady,
          onChanged: (value) {
            step.getReady = value;
            changed();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Start countdown'),
          subtitle: const Text('Say “3, 2, 1, go” before timing starts.'),
          value: step.cueCountdown,
          onChanged: (value) {
            step.cueCountdown = value;
            changed();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Halfway'),
          subtitle: const Text('Announce the halfway point when meaningful.'),
          value: step.halfway,
          onChanged: (value) {
            step.halfway = value;
            changed();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextFormField(
            initialValue: '${step.remainingTimeSeconds}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Remaining-time cue (seconds)',
              helperText: '0 = off. Example: 10 says “10 seconds remaining”.',
            ),
            onChanged: (value) {
              final seconds = int.tryParse(value.trim());
              if (seconds == null || seconds < 0 || seconds > 86400) return;
              step.remainingTimeSeconds = seconds;
              changed();
            },
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Completion cue'),
          subtitle: const Text('Say a short completion cue before moving on.'),
          value: step.completionCue,
          onChanged: (value) {
            step.completionCue = value;
            changed();
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Very short steps automatically skip cues that would be too dense or no longer accurate.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}
