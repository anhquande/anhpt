import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/health.dart';
import '../services/health_analytics.dart';
import '../services/health_store.dart';

enum _ChartRange { week, month, quarter, year }

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final HealthStore _store = HealthStore();
  HealthProfile _profile = const HealthProfile();
  List<WeightMeasurement> _measurements = [];
  _ChartRange _range = _ChartRange.month;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _store.loadProfile();
    final measurements = await _store.loadMeasurements();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _measurements = measurements;
      _loading = false;
    });
  }

  Future<void> _saveMeasurements() async {
    _measurements.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    await _store.saveMeasurements(_measurements);
    if (mounted) setState(() {});
  }

  double _displayWeight(double kg) =>
      _profile.unitSystem == HealthUnitSystem.metric ? kg : kg * 2.2046226218;

  double _toKg(double displayed) =>
      _profile.unitSystem == HealthUnitSystem.metric
          ? displayed
          : displayed / 2.2046226218;

  String get _weightUnit =>
      _profile.unitSystem == HealthUnitSystem.metric ? 'kg' : 'lb';

  Future<void> _editMeasurement([WeightMeasurement? existing]) async {
    final now = existing?.measuredAt ?? DateTime.now();
    final weightController = TextEditingController(
      text: existing == null
          ? ''
          : _displayWeight(existing.weightKg).toStringAsFixed(1),
    );
    final noteController = TextEditingController(text: existing?.note ?? '');
    var selected = now;
    const suggestions = ['Morning', 'After meal', 'Before meal', 'After workout'];

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add weight' : 'Edit measurement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: weightController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Weight ($_weightUnit)'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(_formatDateTime(selected)),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selected,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selected),
                    );
                    if (time == null) return;
                    setDialogState(() {
                      selected = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'Anything useful to remember',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final suggestion in suggestions)
                      ActionChip(
                        label: Text(suggestion),
                        onPressed: () => noteController.text = suggestion,
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(
                  weightController.text.trim().replaceAll(',', '.'),
                );
                if (parsed == null) return;
                final kg = _toKg(parsed);
                if (kg <= 0 || kg >= 500) return;
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final displayed = double.parse(weightController.text.trim().replaceAll(',', '.'));
    final measurement = WeightMeasurement(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      weightKg: _toKg(displayed),
      measuredAt: selected,
      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
    );
    final index = _measurements.indexWhere((value) => value.id == measurement.id);
    if (index >= 0) {
      _measurements[index] = measurement;
    } else {
      _measurements.add(measurement);
    }
    await _saveMeasurements();
  }

  Future<void> _deleteMeasurement(WeightMeasurement value) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete measurement?'),
        content: Text('${_displayWeight(value.weightKg).toStringAsFixed(1)} $_weightUnit · ${_formatDateTime(value.measuredAt)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    _measurements.removeWhere((item) => item.id == value.id);
    await _saveMeasurements();
  }

  Future<void> _editProfile() async {
    final heightController = TextEditingController(
      text: _profile.heightCm?.toStringAsFixed(0) ?? '',
    );
    final yearController = TextEditingController(
      text: _profile.birthYear?.toString() ?? '',
    );
    var sex = _profile.sex;
    var units = _profile.unitSystem;
    final result = await showDialog<HealthProfile>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Health profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<HealthSex>(
                  initialValue: sex,
                  decoration: const InputDecoration(labelText: 'Sex'),
                  items: HealthSex.values
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(() => sex = value ?? sex),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Birth year'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<HealthUnitSystem>(
                  initialValue: units,
                  decoration: const InputDecoration(labelText: 'Display units'),
                  items: const [
                    DropdownMenuItem(value: HealthUnitSystem.metric, child: Text('Metric (kg / cm)')),
                    DropdownMenuItem(value: HealthUnitSystem.imperial, child: Text('Imperial (lb)')),
                  ],
                  onChanged: (value) => setDialogState(() => units = value ?? units),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                HealthProfile(
                  sex: sex,
                  birthYear: int.tryParse(yearController.text.trim()),
                  heightCm: double.tryParse(heightController.text.trim().replaceAll(',', '.')),
                  unitSystem: units,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _store.saveProfile(result);
    setState(() => _profile = result);
  }

  Future<void> _exportData() async {
    final payload = jsonEncode({
      'schemaVersion': 1,
      'profile': _profile.toJson(),
      'measurements': _measurements.map((value) => value.toJson()).toList(),
    });
    final bytes = Uint8List.fromList(utf8.encode(payload));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export AnhPT health data',
      fileName: 'anhpt-health.json',
      bytes: kIsWeb ? bytes : null,
    );
    if (path == null) return;
    if (!kIsWeb) await File(path).writeAsBytes(bytes, flush: true);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Health data exported.')));
  }

  Future<void> _importData() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: kIsWeb,
    );
    if (picked == null) return;
    final file = picked.files.single;
    final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) return;
    var skipped = 0;
    final imported = <WeightMeasurement>[];
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
      for (final raw in (decoded['measurements'] as List? ?? const [])) {
        try {
          final value = WeightMeasurement.fromJson(Map<String, dynamic>.from(raw as Map));
          if (value.weightKg <= 0 || value.weightKg >= 500) {
            skipped++;
          } else {
            imported.add(value);
          }
        } catch (_) {
          skipped++;
        }
      }
      final conflicts = imported.where((incoming) => _measurements.any((current) => current.measuredAt.toUtc() == incoming.measuredAt.toUtc())).length;
      var overwrite = true;
      if (conflicts > 0 && mounted) {
        overwrite = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('$conflicts timestamp conflicts'),
                content: const Text('Overwrite existing measurements with the imported values, or skip conflicts?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Skip')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Overwrite')),
                ],
              ),
            ) ??
            true;
      }
      for (final incoming in imported) {
        final index = _measurements.indexWhere((current) => current.measuredAt.toUtc() == incoming.measuredAt.toUtc());
        if (index >= 0) {
          if (overwrite) _measurements[index] = incoming;
        } else {
          _measurements.add(incoming);
        }
      }
      await _saveMeasurements();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported ${imported.length} measurements${skipped > 0 ? '; skipped $skipped invalid rows' : ''}.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }

  Future<void> _clearMeasurements() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all measurements?'),
        content: const Text('Your Health profile will be kept. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete all')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clearMeasurements();
    setState(() => _measurements = []);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final daily = HealthAnalytics.dailyAverages(_measurements);
    final latest = _measurements.isEmpty ? null : _measurements.first;
    final bmi = HealthAnalytics.bmi(_profile.heightCm, latest?.weightKg);
    final forecasts = HealthAnalytics.forecasts(daily);
    final cutoff = DateTime.now().subtract(Duration(days: switch (_range) {
      _ChartRange.week => 7,
      _ChartRange.month => 30,
      _ChartRange.quarter => 90,
      _ChartRange.year => 365,
    }));
    final visible = daily.where((point) => !point.day.isBefore(cutoff)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') _editProfile();
              if (value == 'import') _importData();
              if (value == 'export') _exportData();
              if (value == 'clear') _clearMeasurements();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Health profile')),
              PopupMenuItem(value: 'import', child: Text('Import health data')),
              PopupMenuItem(value: 'export', child: Text('Export health data')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'clear', child: Text('Delete measurements')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editMeasurement(),
        icon: const Icon(Icons.add),
        label: const Text('Add weight'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current weight', style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 4),
                            Text(
                              latest == null ? '—' : '${_displayWeight(latest.weightKg).toStringAsFixed(1)} $_weightUnit',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (latest != null) Text(_formatDateTime(latest.measuredAt)),
                          ],
                        ),
                      ),
                      FilledButton.icon(onPressed: () => _editMeasurement(), icon: const Icon(Icons.monitor_weight_outlined), label: const Text('Log')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (bmi != null) _BmiCard(bmi: bmi),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Weight trend', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                          SegmentedButton<_ChartRange>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: _ChartRange.week, label: Text('W')),
                              ButtonSegment(value: _ChartRange.month, label: Text('M')),
                              ButtonSegment(value: _ChartRange.quarter, label: Text('Q')),
                              ButtonSegment(value: _ChartRange.year, label: Text('Y')),
                            ],
                            selected: {_range},
                            onSelectionChanged: (value) => setState(() => _range = value.first),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 220,
                        child: visible.length < 2
                            ? const Center(child: Text('Add measurements on different days to see your trend.'))
                            : CustomPaint(painter: _WeightChartPainter(visible, Theme.of(context).colorScheme)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: forecasts.isEmpty
                      ? const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Forecast', style: TextStyle(fontWeight: FontWeight.w700)),
                            SizedBox(height: 6),
                            Text('Add weight measurements regularly. AnhPT will show a forecast only when there is enough consistent data.'),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('If your current weight trend continues', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            for (final forecast in forecasts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('${forecast.targetDate.difference(DateTime.now()).inDays < 15 ? 'Next week' : 'Next month'}: ${_displayWeight(forecast.lowKg).toStringAsFixed(1)}–${_displayWeight(forecast.highKg).toStringAsFixed(1)} $_weightUnit'),
                              ),
                            const Text('Forecasts describe a trend, not the effect of exercise alone.', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Measurements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_measurements.isEmpty)
                const Text('No measurements yet.')
              else
                for (final value in _measurements.take(50))
                  Card(
                    child: ListTile(
                      title: Text('${_displayWeight(value.weightKg).toStringAsFixed(1)} $_weightUnit'),
                      subtitle: Text('${_formatDateTime(value.measuredAt)}${value.note == null ? '' : ' · ${value.note}'}'),
                      onTap: () => _editMeasurement(value),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteMeasurement(value)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BmiCard extends StatelessWidget {
  final double bmi;
  const _BmiCard({required this.bmi});

  @override
  Widget build(BuildContext context) {
    final normalized = ((bmi - 15) / 25).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BMI ${bmi.toStringAsFixed(1)} · ${HealthAnalytics.bmiLabel(bmi)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Row(children: const [
                    Expanded(child: _RangeColor(Colors.orange)),
                    Expanded(flex: 2, child: _RangeColor(Colors.green)),
                    Expanded(child: _RangeColor(Colors.amber)),
                    Expanded(child: _RangeColor(Colors.red)),
                  ]),
                  Positioned(left: math.max(0, constraints.maxWidth * normalized - 7), child: const Icon(Icons.arrow_drop_down, size: 20)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeColor extends StatelessWidget {
  final Color color;
  const _RangeColor(this.color);
  @override
  Widget build(BuildContext context) => Container(height: 10, color: color);
}

class _WeightChartPainter extends CustomPainter {
  final List<DailyWeightPoint> points;
  final ColorScheme scheme;
  _WeightChartPainter(this.points, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((point) => point.averageKg).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final spread = math.max(1.0, maxValue - minValue);
    final first = points.first.day;
    final totalDays = math.max(1, points.last.day.difference(first).inDays);
    final line = Paint()..color = scheme.primary..strokeWidth = 3..style = PaintingStyle.stroke;
    final dot = Paint()..color = scheme.primary..style = PaintingStyle.fill;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = size.width * point.day.difference(first).inDays / totalDays;
      final y = size.height - 16 - ((point.averageKg - minValue) / spread) * (size.height - 32);
      if (index == 0) path.moveTo(x, y); else path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 4, dot);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) => oldDelegate.points != points || oldDelegate.scheme != scheme;
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}
