import 'dart:async';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../data/sample_data.dart';
import '../services/workout_parser.dart';
import '../widgets/common.dart';
import '../widgets/workout_widgets.dart';

class WorkoutEditorScreen extends StatefulWidget {
  final AppController controller;
  final String? workoutId;
  final String? duplicateFromId;
  final bool importMode;
  final String? initialYaml;

  const WorkoutEditorScreen({
    super.key,
    required this.controller,
    this.workoutId,
    this.duplicateFromId,
    this.importMode = false,
    this.initialYaml,
  });

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  late final TextEditingController text;
  String? error;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialYaml != null) {
      text = TextEditingController(text: widget.initialYaml!);
    } else if (widget.workoutId != null) {
      text = TextEditingController(
          text: widget.controller.byId(widget.workoutId!)!.rawYaml);
    } else if (widget.duplicateFromId != null) {
      final w = widget.controller.byId(widget.duplicateFromId!)!;
      text = TextEditingController(
        text: w.rawYaml.replaceFirst(
            RegExp(r'^name:\s*(.+)$', multiLine: true), 'name: ${w.name} Copy'),
      );
    } else if (widget.importMode) {
      text = TextEditingController();
    } else {
      text = TextEditingController(
          text: sampleYaml.replaceFirst(
              'name: Sample Plank', 'name: New Workout'));
    }

    text.addListener(() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 350),
          () => widget.controller.store.saveDraft(text.text));
    });
  }

  Future<void> _save() async {
    try {
      final existing = widget.workoutId == null
          ? null
          : widget.controller.byId(widget.workoutId!);
      final parsed = WorkoutParser.parse(
        text.text,
        id: existing?.id ?? WorkoutParser.generateId(),
        defaultVoiceLanguage: widget.controller.defaultVoiceLanguage,
        favorite: existing?.favorite ?? false,
        createdAt: existing?.createdAt,
      );
      await widget.controller.saveWorkout(parsed);
      await widget.controller.store.clearDraft();
      if (mounted) Navigator.pop(context);
    } on WorkoutValidationException catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> _preview() async {
    try {
      final parsed = WorkoutParser.parse(
        text.text,
        id: widget.workoutId ?? WorkoutParser.generateId(),
        defaultVoiceLanguage: widget.controller.defaultVoiceLanguage,
      );
      setState(() => error = null);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: .85,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(parsed.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                  '${formatDuration(parsed.totalDuration)} · ${parsed.effectiveStepCount} steps'),
              const SizedBox(height: 18),
              WorkoutStructure(nodes: parsed.steps),
            ],
          ),
        ),
      );
    } on WorkoutValidationException catch (e) {
      setState(() => error = e.message);
    }
  }

  void _insert(String value) {
    final sel = text.selection;
    final source = text.text;
    final start = sel.start < 0 ? source.length : sel.start;
    final end = sel.end < 0 ? source.length : sel.end;
    text.text = source.replaceRange(start, end, value);
    text.selection = TextSelection.collapsed(offset: start + value.length);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.importMode ? 'Import YAML' : 'Edit YAML'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              if (error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(error!),
                ),
              Expanded(
                  child: TextField(
                controller: text,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 15, height: 1.45),
                decoration: const InputDecoration(
                    hintText: 'Paste YAML here...',
                    contentPadding: EdgeInsets.all(16)),
              )),
              const SizedBox(height: 8),
              Row(children: [
                OutlinedButton(
                    onPressed: () => _insert('  '), child: const Text('Tab')),
                const SizedBox(width: 6),
                OutlinedButton(
                    onPressed: () => _insert('- '), child: const Text('-')),
                const SizedBox(width: 6),
                OutlinedButton(
                    onPressed: () => _insert(': '), child: const Text(':')),
                const Spacer(),
                TextButton.icon(
                    onPressed: _preview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Preview')),
                IconButton(
                  tooltip: 'YAML Reference',
                  onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(
                            title: Text('YAML Reference'),
                            content: SelectableText(
                                'version: 2\nname: Morning Plank\nstart_countdown: 5s\n\nsteps:\n  - name: Plank\n    duration: 40s\n    guide: Keep your back straight\n  - repeat: 3\n    steps:\n      - name: Nghỉ\n        duration: 20s'),
                          )),
                  icon: const Icon(Icons.help_outline),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    debounce?.cancel();
    text.dispose();
    super.dispose();
  }
}
