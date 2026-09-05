import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/workout_draft.dart';
import '../models/workout.dart';
import '../models/media_asset.dart';
import '../services/workout_parser.dart';
import '../services/workout_serializer.dart';
import '../widgets/coach_recording_card.dart';
import '../widgets/demo_media_source_sheet.dart';
import '../widgets/step_recording_mini_player.dart';
import '../widgets/step_demonstration_button.dart';
import '../widgets/workout_music_card.dart';
import 'workout_editor_screen.dart';

class WorkoutBuilderScreen extends StatefulWidget {
  final AppController controller;
  final String? workoutId;
  final String? duplicateFromId;

  const WorkoutBuilderScreen({
    super.key,
    required this.controller,
    this.workoutId,
    this.duplicateFromId,
  });

  @override
  State<WorkoutBuilderScreen> createState() => _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends State<WorkoutBuilderScreen>
    with SingleTickerProviderStateMixin {
  late WorkoutDraft draft;
  late final TabController _tabController;
  final _overviewScrollController = ScrollController(keepScrollOffset: false);
  final _stepsScrollController = ScrollController(keepScrollOffset: false);
  Workout? _editingWorkout;
  int _selectedTab = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.workoutId != null) {
      final workout = widget.controller.byId(widget.workoutId!);
      if (workout != null) {
        _editingWorkout = workout;
        draft = WorkoutDraft.fromWorkout(workout);
      } else {
        draft = WorkoutDraft(
          voiceLanguage: widget.controller.defaultVoiceLanguage,
          steps: [StepDraft(name: 'Exercise', duration: '30s')],
        );
        error = 'Workout is no longer available.';
      }
    } else if (widget.duplicateFromId != null) {
      final source = widget.controller.byId(widget.duplicateFromId!);
      if (source != null) {
        draft = WorkoutDraft.fromWorkout(source);
        draft.name = '${source.name} Copy';
      } else {
        draft = WorkoutDraft(
          voiceLanguage: widget.controller.defaultVoiceLanguage,
          steps: [StepDraft(name: 'Exercise', duration: '30s')],
        );
        error = 'Source workout is no longer available.';
      }
    } else {
      draft = WorkoutDraft(
        voiceLanguage: widget.controller.defaultVoiceLanguage,
        steps: [
          StepDraft(name: 'Khởi động', duration: '30s'),
          RepeatDraft(
            repeat: 3,
            steps: [
              StepDraft(name: 'Plank', duration: '40s'),
              StepDraft(name: 'Nghỉ', duration: '20s'),
            ],
          ),
        ],
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _overviewScrollController.dispose();
    _stepsScrollController.dispose();
    super.dispose();
  }

  Future<Workout?> _persistDraft({bool close = true}) async {
    try {
      final yaml = WorkoutSerializer.toYaml(draft);
      final existing =
          _editingWorkout ??
          (widget.workoutId == null
              ? null
              : widget.controller.byId(widget.workoutId!));
      final workout = WorkoutParser.parse(
        yaml,
        id: existing?.id ?? WorkoutParser.generateId(),
        defaultVoiceLanguage: widget.controller.defaultVoiceLanguage,
        favorite: existing?.favorite ?? false,
        createdAt: existing?.createdAt,
      );
      await widget.controller.saveWorkout(workout);
      if (widget.workoutId != null) _editingWorkout = workout;
      if (close && mounted) Navigator.pop(context);
      return workout;
    } on WorkoutValidationException catch (e) {
      if (mounted) setState(() => error = e.message);
      return null;
    }
  }

  Future<void> _save() async => _persistDraft();

  Future<void> _recordDescription() async {
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

  Future<void> _recordStep(StepDraft step, String stepKey) async {
    if (widget.workoutId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the workout before recording.')),
      );
      return;
    }
    final saved = await _persistDraft(close: false);
    if (saved == null || !mounted) return;
    final savedStep = _workoutStepAt(saved.steps, stepKey);
    if (savedStep == null) return;
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
              scope: 'step',
              stepKey: stepKey,
              title: 'Step recording: ${savedStep.name}',
              cueDescription: 'Record the spoken cue for this step.',
              scriptText: savedStep.guide,
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

  WorkoutStep? _workoutStepAt(List<WorkoutNode> nodes, String path) {
    final indexes = path.split('.').map(int.tryParse).toList();
    List<WorkoutNode> current = nodes;
    for (var depth = 0; depth < indexes.length; depth++) {
      final index = indexes[depth];
      if (index == null || index < 0 || index >= current.length) return null;
      final node = current[index];
      if (depth == indexes.length - 1) {
        return node is WorkoutStep ? node : null;
      }
      if (node is! RepeatGroup) return null;
      current = node.steps;
    }
    return null;
  }

  void _addStep(List<WorkoutDraftNode> nodes) =>
      setState(() => nodes.add(StepDraft()));

  void _addRepeat(List<WorkoutDraftNode> nodes) {
    setState(
      () => nodes.add(
        RepeatDraft(
          steps: [
            StepDraft(name: 'Exercise', duration: '30s'),
            StepDraft(name: 'Nghỉ', duration: '15s'),
          ],
        ),
      ),
    );
  }

  void _move(List<WorkoutDraftNode> nodes, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= nodes.length) return;
    setState(() {
      final item = nodes.removeAt(index);
      nodes.insert(target, item);
    });
  }

  void _duplicate(List<WorkoutDraftNode> nodes, int index) =>
      setState(() => nodes.insert(index + 1, nodes[index].clone()));

  void _delete(List<WorkoutDraftNode> nodes, int index) =>
      setState(() => nodes.removeAt(index));

  Future<void> _chooseMedia(StepDraft step) async {
    try {
      final asset = await pickDemoMedia(context, widget.controller);
      if (asset == null) return;
      final existingIndex = draft.exercises.indexWhere(
        (exercise) => exercise.id == step.exerciseId,
      );
      final base = step.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      var id = existingIndex >= 0
          ? draft.exercises[existingIndex].id
          : 'exercise-${base.isEmpty ? asset.id.substring(7, 15) : base}';
      var suffix = 2;
      while (draft.exercises.any(
        (exercise) => exercise.id == id && exercise.id != step.exerciseId,
      )) {
        id =
            'exercise-${base.isEmpty ? asset.id.substring(7, 15) : base}-${suffix++}';
      }
      final exercise = Exercise(
        id: id,
        name: step.name.trim(),
        demoMediaId: asset.id,
      );
      setState(() {
        if (existingIndex >= 0) {
          draft.exercises[existingIndex] = exercise;
        } else {
          draft.exercises.add(exercise);
        }
        step.exerciseId = id;
      });
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    }
  }

  void _removeMedia(StepDraft step) {
    setState(() {
      final id = step.exerciseId;
      step.exerciseId = '';
      if (id.isNotEmpty && !_usesExercise(draft.steps, id)) {
        draft.exercises.removeWhere((exercise) => exercise.id == id);
      }
    });
  }

  bool _usesExercise(List<WorkoutDraftNode> nodes, String id) {
    for (final node in nodes) {
      if (node is StepDraft && node.exerciseId == id) return true;
      if (node is RepeatDraft && _usesExercise(node.steps, id)) return true;
    }
    return false;
  }

  Widget _overviewTab(BuildContext context) => ListView(
    key: const PageStorageKey('builder-overview-tab'),
    controller: _overviewScrollController,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: [
      const _BuilderSectionTitle('About'),
      const SizedBox(height: 8),
      TextFormField(
        initialValue: draft.name,
        decoration: const InputDecoration(labelText: 'Workout name'),
        onChanged: (v) => draft.name = v,
      ),
      const SizedBox(height: 10),
      TextFormField(
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
                  audioPath: widget.controller.resolveAudioSource(
                    workout.recording!,
                  ),
                  onManage: _recordDescription,
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 10),
      TextFormField(
        initialValue: draft.tags.join(', '),
        decoration: const InputDecoration(
          labelText: 'Tags',
          hintText: 'core, plank, beginner',
        ),
        onChanged: (value) => draft.tags = value
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
      ),
      const SizedBox(height: 20),
      const _BuilderSectionTitle('Workout options'),
      const SizedBox(height: 8),
      _BuilderOptionContainer(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.power_settings_new),
          title: const Text('After workout: Shut down or exit'),
          subtitle: Text(
            draft.completionAction == 'shutdown_or_exit'
                ? 'Enabled — Windows shuts down immediately and may discard unsaved work.'
                : 'Off — the completion screen stays open normally.',
          ),
          value: draft.completionAction == 'shutdown_or_exit',
          onChanged: (value) => setState(() {
            draft.completionAction = value ? 'shutdown_or_exit' : 'none';
          }),
        ),
      ),
      const SizedBox(height: 8),
      _BuilderOptionContainer(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.screen_lock_landscape_outlined),
          title: const Text('Turn off screen after starting'),
          subtitle: Text(
            draft.screenOffAfterStart.isNotEmpty
                ? 'Enabled — Windows turns off the monitor; Android blacks out the app display after 10 seconds.'
                : 'Off — the display remains unchanged.',
          ),
          value: draft.screenOffAfterStart.isNotEmpty,
          onChanged: (value) => setState(() {
            draft.screenOffAfterStart = value ? '10s' : '';
          }),
        ),
      ),
      const SizedBox(height: 8),
      _BuilderOptionContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextFormField(
            initialValue: draft.startCountdown,
            decoration: const InputDecoration(
              labelText: 'Start countdown',
              prefixIcon: Icon(Icons.timer_outlined),
            ),
            onChanged: (v) => draft.startCountdown = v,
          ),
        ),
      ),
      const SizedBox(height: 8),
      _BuilderOptionContainer(
        child: ExpansionTile(
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: const Icon(Icons.videocam_outlined),
          title: const Text(
            'Video / Camera',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            draft.videoSettingsEnabled
                ? '${draft.videoAutoEnable ? 'Auto on' : 'Manual'} · ${draft.videoCamera} · ${draft.videoLayout.replaceAll('_', ' ')}'
                : 'Use global workout camera defaults',
          ),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use workout-specific video settings'),
              subtitle: const Text('Save camera behavior in this workout YAML.'),
              value: draft.videoSettingsEnabled,
              onChanged: (value) => setState(() {
                draft.videoSettingsEnabled = value;
              }),
            ),
            if (draft.videoSettingsEnabled) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Automatically enable user video'),
                subtitle: const Text('Open the selected camera when the workout starts.'),
                value: draft.videoAutoEnable,
                onChanged: (value) => setState(() {
                  draft.videoAutoEnable = value;
                }),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: draft.videoLayout,
                decoration: const InputDecoration(labelText: 'Video layout'),
                items: const [
                  DropdownMenuItem(
                    value: 'picture_in_picture',
                    child: Text('Demo main / Camera PiP'),
                  ),
                  DropdownMenuItem(
                    value: 'camera_picture_in_picture',
                    child: Text('Camera main / Demo PiP'),
                  ),
                  DropdownMenuItem(value: 'split', child: Text('Split')),
                  DropdownMenuItem(value: 'overlay', child: Text('Overlay')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => draft.videoLayout = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: draft.videoCamera,
                decoration: const InputDecoration(labelText: 'Preferred camera'),
                items: const [
                  DropdownMenuItem(value: 'front', child: Text('Front camera')),
                  DropdownMenuItem(value: 'back', child: Text('Rear camera')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => draft.videoCamera = value);
                  }
                },
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _BuilderSectionTitle('Audio'),
      const SizedBox(height: 8),
      _BuilderOptionContainer(
        child: ExpansionTile(
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: const Icon(Icons.record_voice_over_outlined),
          title: const Text(
            'Voice settings',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: draft.voiceLanguage,
              decoration: const InputDecoration(labelText: 'Language'),
              items: const [
                DropdownMenuItem(value: 'vi', child: Text('Vietnamese')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) => setState(() => draft.voiceLanguage = v ?? 'vi'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Announce step name'),
              subtitle: const Text('Say the step name when a new step begins.'),
              value: draft.announceStepName,
              onChanged: (v) => setState(() => draft.announceStepName = v),
            ),
            const Divider(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Voice timing',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Elapsed time'),
              subtitle: const Text('Announce each elapsed second: “1, 2, 3…”'),
              value: draft.announceElapsedTime,
              onChanged: (v) => setState(() => draft.announceElapsedTime = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Periodic time remaining'),
              subtitle: const Text('Periodically say how much time is left.'),
              value: draft.announceInterval,
              onChanged: (v) => setState(() => draft.announceInterval = v),
            ),
            if (draft.announceInterval) ...[
              const SizedBox(height: 4),
              _TimingDurationPicker(
                label: 'Every',
                value: draft.announceEvery,
                choices: const ['5s', '10s', '15s', '30s', '60s'],
                onChanged: (value) =>
                    setState(() => draft.announceEvery = value),
              ),
              const SizedBox(height: 8),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Final countdown'),
              subtitle: const Text(
                'Count down every second before the step ends.',
              ),
              value: draft.announceFinalCountdown,
              onChanged: (v) =>
                  setState(() => draft.announceFinalCountdown = v),
            ),
            if (draft.announceFinalCountdown) ...[
              const SizedBox(height: 4),
              _TimingDurationPicker(
                label: 'Start at',
                value: draft.countdownFrom,
                choices: const ['3s', '5s', '10s', '15s'],
                onChanged: (value) =>
                    setState(() => draft.countdownFrom = value),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (_editingWorkout case final workout?)
        WorkoutMusicCard(
          key: ValueKey('builder-music-${workout.id}'),
          controller: widget.controller,
          workout: workout,
        )
      else
        _BuilderOptionContainer(
          child: ExpansionTile(
            maintainState: true,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: const Icon(Icons.music_note_outlined),
            title: const Text(
              'Background music',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              draft.backgroundMusicEnabled
                  ? 'Enabled · ${(draft.backgroundMusicVolume * 100).round()}%'
                  : 'Off',
            ),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Play background music'),
                subtitle: const Text('Duck the track while the coach speaks.'),
                value: draft.backgroundMusicEnabled,
                onChanged: (value) =>
                    setState(() => draft.backgroundMusicEnabled = value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: draft.backgroundMusicName,
                decoration: const InputDecoration(labelText: 'Track name'),
                onChanged: (value) => draft.backgroundMusicName = value,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: draft.backgroundMusicSource,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  hintText: 'asset:audio/music.mp3 or imported file path',
                ),
                onChanged: (value) => draft.backgroundMusicSource = value,
              ),
              const SizedBox(height: 14),
              Text(
                'Volume ${(draft.backgroundMusicVolume * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: draft.backgroundMusicVolume.clamp(0.0, 1.0),
                divisions: 20,
                label: '${(draft.backgroundMusicVolume * 100).round()}%',
                onChanged: (value) =>
                    setState(() => draft.backgroundMusicVolume = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: draft.backgroundMusicDucking,
                decoration: const InputDecoration(labelText: 'Coach ducking'),
                items: const [
                  DropdownMenuItem(value: 'off', child: Text('Off')),
                  DropdownMenuItem(value: 'gentle', child: Text('Gentle')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(
                    value: 'very_high',
                    child: Text('Very high'),
                  ),
                ],
                onChanged: (value) => setState(
                  () => draft.backgroundMusicDucking = value ?? 'gentle',
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _stepsTab(BuildContext context) => ListView(
    key: const PageStorageKey('builder-steps-tab'),
    controller: _stepsScrollController,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: [
      _NodeList(
        nodes: draft.steps,
        depth: 0,
        changed: () => setState(() {}),
        move: _move,
        duplicate: _duplicate,
        delete: _delete,
        addStep: _addStep,
        addRepeat: _addRepeat,
        exerciseFor: (id) {
          for (final exercise in draft.exercises) {
            if (exercise.id == id) return exercise;
          }
          return null;
        },
        chooseMedia: _chooseMedia,
        removeMedia: _removeMedia,
        recordStep: _recordStep,
        resolveAsset: widget.controller.mediaAsset,
        resolveUri: widget.controller.resolveMediaUri,
        resolveRecording: widget.controller.resolveAudioSource,
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _addStep(draft.steps),
              icon: const Icon(Icons.add),
              label: const Text('Add Step'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _addRepeat(draft.steps),
              icon: const Icon(Icons.repeat),
              label: const Text('Add Repeat'),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutId == null ? 'New workout' : 'Edit workout'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkoutEditorScreen(
                  controller: widget.controller,
                  initialYaml: WorkoutSerializer.toYaml(draft),
                ),
              ),
            ),
            icon: const Icon(Icons.code),
            label: const Text('YAML'),
          ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(error!),
                  ),
                ),
              TabBar(
                controller: _tabController,
                onTap: (index) => setState(() => _selectedTab = index),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Steps'),
                ],
              ),
              Expanded(
                child: _selectedTab == 0
                    ? _overviewTab(context)
                    : _stepsTab(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimingDurationPicker extends StatelessWidget {
  final String label;
  final String value;
  final List<String> choices;
  final ValueChanged<String> onChanged;

  const _TimingDurationPicker({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final values = <String>{value, ...choices}.toList();
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.schedule_outlined),
      ),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _BuilderSectionTitle extends StatelessWidget {
  final String text;

  const _BuilderSectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleSmall
        ?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _BuilderOptionContainer extends StatelessWidget {
  final Widget child;

  const _BuilderOptionContainer({required this.child});

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: child,
    ),
  );
}

class _NodeList extends StatelessWidget {
  final List<WorkoutDraftNode> nodes;
  final int depth;
  final VoidCallback changed;
  final void Function(List<WorkoutDraftNode>, int, int) move;
  final void Function(List<WorkoutDraftNode>, int) duplicate;
  final void Function(List<WorkoutDraftNode>, int) delete;
  final void Function(List<WorkoutDraftNode>) addStep;
  final void Function(List<WorkoutDraftNode>) addRepeat;
  final Exercise? Function(String id) exerciseFor;
  final Future<void> Function(StepDraft step) chooseMedia;
  final void Function(StepDraft step) removeMedia;
  final Future<void> Function(StepDraft step, String stepKey) recordStep;
  final Future<MediaAsset?> Function(String id) resolveAsset;
  final Future<Uri?> Function(String id) resolveUri;
  final String Function(String source) resolveRecording;
  final String pathPrefix;

  const _NodeList({
    required this.nodes,
    required this.depth,
    required this.changed,
    required this.move,
    required this.duplicate,
    required this.delete,
    required this.addStep,
    required this.addRepeat,
    required this.exerciseFor,
    required this.chooseMedia,
    required this.removeMedia,
    required this.recordStep,
    required this.resolveAsset,
    required this.resolveUri,
    required this.resolveRecording,
    this.pathPrefix = '',
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < nodes.length; i++)
        Padding(
          key: ObjectKey(nodes[i]),
          padding: EdgeInsets.only(left: depth * 12.0, bottom: 10),
          child: nodes[i] is StepDraft
              ? _StepCard(
                  step: nodes[i] as StepDraft,
                  changed: changed,
                  up: () => move(nodes, i, -1),
                  down: () => move(nodes, i, 1),
                  copy: () => duplicate(nodes, i),
                  remove: () => delete(nodes, i),
                  exercise: exerciseFor((nodes[i] as StepDraft).exerciseId),
                  chooseMedia: () => chooseMedia(nodes[i] as StepDraft),
                  removeMedia: () => removeMedia(nodes[i] as StepDraft),
                  record: () => recordStep(
                    nodes[i] as StepDraft,
                    pathPrefix.isEmpty ? '$i' : '$pathPrefix.$i',
                  ),
                  resolveAsset: resolveAsset,
                  resolveUri: resolveUri,
                  resolveRecording: resolveRecording,
                )
              : _RepeatCard(
                  group: nodes[i] as RepeatDraft,
                  children: _NodeList(
                    nodes: (nodes[i] as RepeatDraft).steps,
                    depth: depth + 1,
                    changed: changed,
                    move: move,
                    duplicate: duplicate,
                    delete: delete,
                    addStep: addStep,
                    addRepeat: addRepeat,
                    exerciseFor: exerciseFor,
                    chooseMedia: chooseMedia,
                    removeMedia: removeMedia,
                    recordStep: recordStep,
                    resolveAsset: resolveAsset,
                    resolveUri: resolveUri,
                    resolveRecording: resolveRecording,
                    pathPrefix: pathPrefix.isEmpty ? '$i' : '$pathPrefix.$i',
                  ),
                  up: () => move(nodes, i, -1),
                  down: () => move(nodes, i, 1),
                  copy: () => duplicate(nodes, i),
                  remove: () => delete(nodes, i),
                  addStep: () => addStep((nodes[i] as RepeatDraft).steps),
                  addRepeat: () => addRepeat((nodes[i] as RepeatDraft).steps),
                ),
        ),
    ],
  );
}

class _StepCard extends StatelessWidget {
  final StepDraft step;
  final VoidCallback changed, up, down, copy, remove;
  final Exercise? exercise;
  final Future<void> Function() chooseMedia;
  final VoidCallback removeMedia;
  final Future<void> Function() record;
  final Future<MediaAsset?> Function(String id) resolveAsset;
  final Future<Uri?> Function(String id) resolveUri;
  final String Function(String source) resolveRecording;

  const _StepCard({
    required this.step,
    required this.changed,
    required this.up,
    required this.down,
    required this.copy,
    required this.remove,
    required this.exercise,
    required this.chooseMedia,
    required this.removeMedia,
    required this.record,
    required this.resolveAsset,
    required this.resolveUri,
    required this.resolveRecording,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Step',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(onPressed: up, icon: const Icon(Icons.arrow_upward)),
              IconButton(
                onPressed: down,
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                onPressed: copy,
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                onPressed: remove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: step.name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (v) => step.name = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: step.duration,
                  decoration: const InputDecoration(labelText: 'Duration'),
                  onChanged: (v) => step.duration = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: step.guide,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Guide (optional)'),
            onChanged: (v) => step.guide = v,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (step.recording.isEmpty)
                IconButton.filledTonal(
                  tooltip: 'Record step cue',
                  onPressed: () => record(),
                  icon: const Icon(Icons.mic_none_outlined),
                )
              else
                StepRecordingMiniPlayer(
                  audioPath: resolveRecording(step.recording),
                  onManage: () => record(),
                ),
              const SizedBox(width: 6),
              if (exercise?.demoMediaId == null)
                IconButton.filledTonal(
                  tooltip: 'Add demonstration media',
                  onPressed: () => chooseMedia(),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                )
              else
                StepDemonstrationButton(
                  key: ValueKey(exercise!.demoMediaId),
                  mediaId: exercise!.demoMediaId!,
                  resolveAsset: resolveAsset,
                  resolveUri: resolveUri,
                  onReplace: chooseMedia,
                  onRemove: () async => removeMedia(),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Voice timing'),
            subtitle: const Text('Interval / continuous / final countdown'),
            value: step.countdown,
            onChanged: (v) {
              step.countdown = v;
              changed();
            },
          ),
        ],
      ),
    ),
  );
}

class _RepeatCard extends StatelessWidget {
  final RepeatDraft group;
  final Widget children;
  final VoidCallback up, down, copy, remove, addStep, addRepeat;

  const _RepeatCard({
    required this.group,
    required this.children,
    required this.up,
    required this.down,
    required this.copy,
    required this.remove,
    required this.addStep,
    required this.addRepeat,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.repeat),
              const SizedBox(width: 6),
              const Text(
                'Repeat',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: '${group.repeat}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Times'),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null) group.repeat = n;
                  },
                ),
              ),
              const Spacer(),
              IconButton(onPressed: up, icon: const Icon(Icons.arrow_upward)),
              IconButton(
                onPressed: down,
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                onPressed: copy,
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                onPressed: remove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          children,
          Row(
            children: [
              TextButton.icon(
                onPressed: addStep,
                icon: const Icon(Icons.add),
                label: const Text('Step'),
              ),
              TextButton.icon(
                onPressed: addRepeat,
                icon: const Icon(Icons.repeat),
                label: const Text('Repeat'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
