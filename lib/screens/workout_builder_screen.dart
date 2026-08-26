import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/workout_draft.dart';
import '../services/workout_parser.dart';
import '../services/workout_serializer.dart';
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

class _WorkoutBuilderScreenState extends State<WorkoutBuilderScreen> {
  late WorkoutDraft draft;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.workoutId != null) {
      draft = WorkoutDraft.fromWorkout(widget.controller.byId(widget.workoutId!)!);
    } else if (widget.duplicateFromId != null) {
      final source = widget.controller.byId(widget.duplicateFromId!)!;
      draft = WorkoutDraft.fromWorkout(source);
      draft.name = '${source.name} Copy';
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

  Future<void> _save() async {
    try {
      final yaml = WorkoutSerializer.toYaml(draft);
      final existing = widget.workoutId == null
          ? null
          : widget.controller.byId(widget.workoutId!);
      final workout = WorkoutParser.parse(
        yaml,
        id: existing?.id ?? WorkoutParser.generateId(),
        defaultVoiceLanguage: widget.controller.defaultVoiceLanguage,
        favorite: existing?.favorite ?? false,
        createdAt: existing?.createdAt,
      );
      await widget.controller.saveWorkout(workout);
      if (mounted) Navigator.pop(context);
    } on WorkoutValidationException catch (e) {
      setState(() => error = e.message);
    }
  }

  void _addStep(List<WorkoutDraftNode> nodes) {
    setState(() => nodes.add(StepDraft()));
  }

  void _addRepeat(List<WorkoutDraftNode> nodes) {
    setState(() => nodes.add(RepeatDraft(
          steps: [
            StepDraft(name: 'Exercise', duration: '30s'),
            StepDraft(name: 'Nghỉ', duration: '15s'),
          ],
        )));
  }

  void _move(List<WorkoutDraftNode> nodes, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= nodes.length) return;
    setState(() {
      final item = nodes.removeAt(index);
      nodes.insert(target, item);
    });
  }

  void _duplicate(List<WorkoutDraftNode> nodes, int index) {
    setState(() => nodes.insert(index + 1, nodes[index].clone()));
  }

  void _delete(List<WorkoutDraftNode> nodes, int index) {
    setState(() => nodes.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Builder'),
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
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              if (error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(error!),
                  ),
                ),
              TextFormField(
                initialValue: draft.name,
                decoration: const InputDecoration(labelText: 'Workout name'),
                onChanged: (v) => draft.name = v,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: draft.description,
                decoration: const InputDecoration(labelText: 'Description'),
                onChanged: (v) => draft.description = v,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: draft.startCountdown,
                decoration: const InputDecoration(labelText: 'Start countdown'),
                onChanged: (v) => draft.startCountdown = v,
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Voice settings', style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: draft.voiceLanguage,
                    decoration: const InputDecoration(labelText: 'Language'),
                    items: const [
                      DropdownMenuItem(value: 'vi', child: Text('Vietnamese')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) => setState(() => draft.voiceLanguage = v ?? 'vi'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: draft.voiceMode,
                    decoration: const InputDecoration(labelText: 'Mode'),
                    items: const [
                      DropdownMenuItem(value: 'continuous', child: Text('Continuous')),
                      DropdownMenuItem(value: 'interval', child: Text('Interval')),
                      DropdownMenuItem(value: 'ending', child: Text('Ending countdown')),
                      DropdownMenuItem(value: 'combined', child: Text('Combined')),
                    ],
                    onChanged: (v) => setState(() => draft.voiceMode = v ?? 'combined'),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextFormField(
                      initialValue: draft.announceEvery,
                      decoration: const InputDecoration(labelText: 'Announce every'),
                      onChanged: (v) => draft.announceEvery = v,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(
                      initialValue: draft.countdownFrom,
                      decoration: const InputDecoration(labelText: 'Countdown from'),
                      onChanged: (v) => draft.countdownFrom = v,
                    )),
                  ]),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Announce step name'),
                    value: draft.announceStepName,
                    onChanged: (v) => setState(() => draft.announceStepName = v),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Workout', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              _NodeList(
                nodes: draft.steps,
                depth: 0,
                changed: () => setState(() {}),
                move: _move,
                duplicate: _duplicate,
                delete: _delete,
                addStep: _addStep,
                addRepeat: _addRepeat,
              ),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _addStep(draft.steps),
                  icon: const Icon(Icons.add), label: const Text('Add Step'),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _addRepeat(draft.steps),
                  icon: const Icon(Icons.repeat), label: const Text('Add Repeat'),
                )),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
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

  const _NodeList({required this.nodes, required this.depth, required this.changed, required this.move,
    required this.duplicate, required this.delete, required this.addStep, required this.addRepeat});

  @override
  Widget build(BuildContext context) => Column(children: [
    for (var i = 0; i < nodes.length; i++)
      Padding(
        padding: EdgeInsets.only(left: depth * 12.0, bottom: 10),
        child: nodes[i] is StepDraft
            ? _StepCard(
                step: nodes[i] as StepDraft,
                changed: changed,
                up: () => move(nodes, i, -1), down: () => move(nodes, i, 1),
                copy: () => duplicate(nodes, i), remove: () => delete(nodes, i),
              )
            : _RepeatCard(
                group: nodes[i] as RepeatDraft,
                children: _NodeList(
                  nodes: (nodes[i] as RepeatDraft).steps, depth: depth + 1, changed: changed,
                  move: move, duplicate: duplicate, delete: delete, addStep: addStep, addRepeat: addRepeat,
                ),
                up: () => move(nodes, i, -1), down: () => move(nodes, i, 1),
                copy: () => duplicate(nodes, i), remove: () => delete(nodes, i),
                addStep: () => addStep((nodes[i] as RepeatDraft).steps),
                addRepeat: () => addRepeat((nodes[i] as RepeatDraft).steps),
              ),
      ),
  ]);
}

class _StepCard extends StatelessWidget {
  final StepDraft step;
  final VoidCallback changed, up, down, copy, remove;
  const _StepCard({required this.step, required this.changed, required this.up, required this.down,
    required this.copy, required this.remove});

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.timer_outlined), const SizedBox(width: 6),
        const Expanded(child: Text('Step', style: TextStyle(fontWeight: FontWeight.bold))),
        IconButton(onPressed: up, icon: const Icon(Icons.arrow_upward)),
        IconButton(onPressed: down, icon: const Icon(Icons.arrow_downward)),
        IconButton(onPressed: copy, icon: const Icon(Icons.copy_outlined)),
        IconButton(onPressed: remove, icon: const Icon(Icons.delete_outline)),
      ]),
      Row(children: [
        Expanded(flex: 3, child: TextFormField(initialValue: step.name,
          decoration: const InputDecoration(labelText: 'Name'), onChanged: (v) => step.name = v)),
        const SizedBox(width: 8),
        Expanded(child: TextFormField(initialValue: step.duration,
          decoration: const InputDecoration(labelText: 'Duration'), onChanged: (v) => step.duration = v)),
      ]),
      const SizedBox(height: 8),
      TextFormField(initialValue: step.guide, minLines: 1, maxLines: 4,
        decoration: const InputDecoration(labelText: 'Guide (optional)'), onChanged: (v) => step.guide = v),
    ]),
  ));
}

class _RepeatCard extends StatelessWidget {
  final RepeatDraft group;
  final Widget children;
  final VoidCallback up, down, copy, remove, addStep, addRepeat;
  const _RepeatCard({required this.group, required this.children, required this.up, required this.down,
    required this.copy, required this.remove, required this.addStep, required this.addRepeat});

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.repeat), const SizedBox(width: 6),
        const Text('Repeat', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10),
        SizedBox(width: 80, child: TextFormField(
          initialValue: '${group.repeat}', keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Times'),
          onChanged: (v) { final n = int.tryParse(v); if (n != null) group.repeat = n; },
        )),
        const Spacer(),
        IconButton(onPressed: up, icon: const Icon(Icons.arrow_upward)),
        IconButton(onPressed: down, icon: const Icon(Icons.arrow_downward)),
        IconButton(onPressed: copy, icon: const Icon(Icons.copy_outlined)),
        IconButton(onPressed: remove, icon: const Icon(Icons.delete_outline)),
      ]),
      const SizedBox(height: 8), children,
      Row(children: [
        TextButton.icon(onPressed: addStep, icon: const Icon(Icons.add), label: const Text('Step')),
        TextButton.icon(onPressed: addRepeat, icon: const Icon(Icons.repeat), label: const Text('Repeat')),
      ]),
    ]),
  ));
}
