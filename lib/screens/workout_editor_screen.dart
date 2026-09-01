import 'dart:async';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../data/sample_data.dart';
import '../models/workout_video_settings.dart';
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
  bool _videoSettingsEnabled = false;
  bool _videoAutoEnable = false;
  String _videoLayout = WorkoutVideoSettings.defaultLayout;
  String _videoCamera = WorkoutVideoSettings.defaultCamera;

  @override
  void initState() {
    super.initState();
    if (widget.initialYaml != null) {
      text = TextEditingController(text: widget.initialYaml!);
    } else if (widget.workoutId != null) {
      text = TextEditingController(
        text: widget.controller.byId(widget.workoutId!)!.rawYaml,
      );
    } else if (widget.duplicateFromId != null) {
      final w = widget.controller.byId(widget.duplicateFromId!)!;
      text = TextEditingController(
        text: w.rawYaml.replaceFirst(
          RegExp(r'^name:\s*(.+)$', multiLine: true),
          'name: ${w.name} Copy',
        ),
      );
    } else if (widget.importMode) {
      text = TextEditingController();
    } else {
      text = TextEditingController(
        text: sampleYaml.replaceFirst(
          'name: Sample Plank',
          'name: New Workout',
        ),
      );
    }

    _readVideoSettings();
    text.addListener(() {
      debounce?.cancel();
      debounce = Timer(
        const Duration(milliseconds: 350),
        () => widget.controller.store.saveDraft(text.text),
      );
    });
  }

  void _readVideoSettings() {
    final settings = WorkoutVideoSettings.fromYaml(text.text);
    _videoSettingsEnabled = settings != null;
    _videoAutoEnable = settings?.autoEnable ?? false;
    _videoLayout = settings?.layout ?? WorkoutVideoSettings.defaultLayout;
    _videoCamera = settings?.camera ?? WorkoutVideoSettings.defaultCamera;
  }

  void _writeVideoSettings() {
    final sourceLines = text.text.split('\n');
    final output = <String>[];
    var skippingVideo = false;
    for (final line in sourceLines) {
      if (!skippingVideo && line.trim() == 'video:' && line.startsWith('video:')) {
        skippingVideo = true;
        continue;
      }
      if (skippingVideo) {
        if (line.trim().isEmpty || line.startsWith(' ') || line.startsWith('\t')) {
          continue;
        }
        skippingVideo = false;
      }
      output.add(line);
    }

    if (_videoSettingsEnabled) {
      final block = <String>[
        'video:',
        '  auto_enable: $_videoAutoEnable',
        '  layout: $_videoLayout',
        '  camera: $_videoCamera',
        '',
      ];
      var insertAt = output.indexWhere(
        (line) => line.startsWith('start_countdown:'),
      );
      if (insertAt < 0) {
        insertAt = output.indexWhere((line) => line.startsWith('steps:'));
      }
      if (insertAt < 0) insertAt = output.length;
      output.insertAll(insertAt, block);
    }

    final updated = output.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
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
              Text(
                parsed.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatDuration(parsed.totalDuration)} · ${parsed.effectiveStepCount} steps',
              ),
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
            child: Column(
              children: [
                if (error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(error!),
                  ),
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    leading: const Icon(Icons.videocam_outlined),
                    title: const Text('Video / Camera settings'),
                    subtitle: Text(
                      _videoSettingsEnabled
                          ? '${_videoAutoEnable ? 'Auto on' : 'Manual'} · $_videoCamera · ${_videoLayout.replaceAll('_', ' ')}'
                          : 'Use global workout camera defaults',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Use workout-specific video settings'),
                        subtitle: const Text(
                          'Store camera behavior in this workout YAML.',
                        ),
                        value: _videoSettingsEnabled,
                        onChanged: (value) => setState(() {
                          _videoSettingsEnabled = value;
                          _writeVideoSettings();
                        }),
                      ),
                      if (_videoSettingsEnabled) ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Automatically enable user video'),
                          value: _videoAutoEnable,
                          onChanged: (value) => setState(() {
                            _videoAutoEnable = value;
                            _writeVideoSettings();
                          }),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _videoLayout,
                          decoration: const InputDecoration(
                            labelText: 'Video layout',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'picture_in_picture',
                              child: Text('Demo main / Camera PiP'),
                            ),
                            DropdownMenuItem(
                              value: 'camera_picture_in_picture',
                              child: Text('Camera main / Demo PiP'),
                            ),
                            DropdownMenuItem(
                              value: 'split',
                              child: Text('Split'),
                            ),
                            DropdownMenuItem(
                              value: 'overlay',
                              child: Text('Overlay'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _videoLayout = value;
                              _writeVideoSettings();
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _videoCamera,
                          decoration: const InputDecoration(
                            labelText: 'Preferred camera',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'front',
                              child: Text('Front camera'),
                            ),
                            DropdownMenuItem(
                              value: 'back',
                              child: Text('Rear camera'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _videoCamera = value;
                              _writeVideoSettings();
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: text,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      height: 1.45,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Paste YAML here...',
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _insert('  '),
                      child: const Text('Tab'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () => _insert('- '),
                      child: const Text('-'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () => _insert(': '),
                      child: const Text(':'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _preview,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Preview'),
                    ),
                    IconButton(
                      tooltip: 'YAML Reference',
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const AlertDialog(
                          title: Text('YAML Reference'),
                          content: SelectableText(
                            'version: 2\nname: Morning Plank\nvideo:\n  auto_enable: true\n  layout: picture_in_picture\n  camera: front\nstart_countdown: 5s\n\nsteps:\n  - name: Plank\n    duration: 40s\n    guide: Keep your back straight',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.help_outline),
                    ),
                  ],
                ),
              ],
            ),
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
