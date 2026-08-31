from pathlib import Path
import re

builder_path = Path('lib/screens/workout_builder_screen.dart')
builder = builder_path.read_text()

marker = "  Future<void> _save() async => _persistDraft();\n\n"
method = """  Future<void> _recordDescription() async {
    if (widget.workoutId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the workout before recording.')),
      );
      return;
    }
    final saved = await _persistDraft(close: false);
    if (saved == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: CoachRecordingCard(
              controller: widget.controller,
              workout: saved,
              scope: 'description',
              title: 'Description recording',
              cueDescription: 'Record the spoken description for this workout.',
              scriptText: saved.description,
              showCloseButton: true,
              closeAfterSave: true,
            ),
          ),
        ),
      ),
    );
    final latest = widget.controller.byId(saved.id);
    if (latest != null && mounted) {
      _editingWorkout = latest;
      setState(() => draft = WorkoutDraft.fromWorkout(latest));
    }
  }

"""
if marker not in builder:
    raise SystemExit('builder save marker not found')
builder = builder.replace(marker, marker + method, 1)

description_block = """          TextFormField(
            initialValue: draft.description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description'),
            onChanged: (v) => draft.description = v,
          ),
          const SizedBox(height: 10),
"""
description_with_recording = """          TextFormField(
            initialValue: draft.description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description'),
            onChanged: (v) => draft.description = v,
          ),
          if (_editingWorkout case final workout?) ...[
            const SizedBox(height: 8),
            _BuilderOptionContainer(
              child: Row(
                children: [
                  const Icon(Icons.mic_none_outlined),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description recording',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text('Spoken version of the workout description'),
                      ],
                    ),
                  ),
                  if (workout.recording == null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Record description',
                      onPressed: _recordDescription,
                      icon: const Icon(Icons.add_circle_outline),
                    )
                  else
                    StepRecordingMiniPlayer(
                      audioPath:
                          widget.controller.resolveAudioSource(workout.recording!),
                      onManage: _recordDescription,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
"""
if description_block not in builder:
    raise SystemExit('builder description block not found')
builder = builder.replace(description_block, description_with_recording, 1)
builder_path.write_text(builder)

detail_path = Path('lib/screens/workout_detail_screen.dart')
detail = detail_path.read_text()
detail, count = re.subn(
    r"\n  Future<void> _openIntroductionRecording\(.*?\n  Future<void> _browseStepMedia",
    "\n  Future<void> _browseStepMedia",
    detail,
    count=1,
    flags=re.S,
)
if count != 1:
    raise SystemExit(f'open introduction method removal count={count}')
detail, count = re.subn(
    r"\n  Widget _introductionOption\(.*?\n  @override\n  Widget build",
    "\n  @override\n  Widget build",
    detail,
    count=1,
    flags=re.S,
)
if count != 1:
    raise SystemExit(f'introduction option removal count={count}')
old_detail_option = """                            const SizedBox(height: 8),
                            _introductionOption(context, controller, workout),
                            const SizedBox(height: 20),
                            const _SectionTitle('Audio'),"""
new_detail_option = """                            const SizedBox(height: 20),
                            const _SectionTitle('Audio'),"""
if old_detail_option not in detail:
    raise SystemExit('detail introduction invocation not found')
detail = detail.replace(old_detail_option, new_detail_option, 1)
detail_path.write_text(detail)

widget_test_path = Path('test/widget_test.dart')
widget_test = widget_test_path.read_text()
for line in [
    "    expect(find.text('Introduction'), findsOneWidget);\n",
    "    expect(find.text('Workout introduction recording'), findsOneWidget);\n",
    "    expect(find.byTooltip('Record workout introduction'), findsOneWidget);\n",
]:
    widget_test = widget_test.replace(line, '')
widget_test_path.write_text(widget_test)

coach_test_path = Path('test/coach_recording_test.dart')
coach_test = coach_test_path.read_text()
pattern = r"  testWidgets\('assigned introduction uses the shared recording mini player',.*?\n  \}\);\n\n  for \(final scope"
replacement = """  testWidgets('assigned description recording is managed from edit overview',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());
    controller.workouts = [
      WorkoutParser.parse('''
version: 2
name: Recorded introduction
description: Keep your core engaged.
recording: coach_recordings/introduction.m4a
steps:
  - name: Plank
''', id: 'workout-intro', defaultVoiceLanguage: 'en'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: WorkoutBuilderScreen(
        controller: controller,
        workoutId: 'workout-intro',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Description recording'), findsOneWidget);
    expect(find.byTooltip('Play recording'), findsOneWidget);
    expect(find.byTooltip('Record description'), findsNothing);
  });

  for (final scope"""
coach_test, count = re.subn(pattern, replacement, coach_test, count=1, flags=re.S)
if count != 1:
    raise SystemExit(f'coach test replacement count={count}')
if "import 'package:anhpt/screens/workout_builder_screen.dart';" not in coach_test:
    coach_test = coach_test.replace(
        "import 'package:anhpt/screens/workout_detail_screen.dart';\n",
        "import 'package:anhpt/screens/workout_detail_screen.dart';\nimport 'package:anhpt/screens/workout_builder_screen.dart';\n",
        1,
    )
coach_test_path.write_text(coach_test)
