import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/health.dart';
import '../models/local_profile.dart';
import '../services/health_analytics.dart';
import '../services/health_store.dart';
import '../widgets/profile_editor_dialog.dart';

enum _ChartRange { week, month, quarter, year }
enum _MeasurementSort { date, weight, note }

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final HealthStore _store = HealthStore();
  final ScrollController _measurementScrollController = ScrollController();
  LocalProfile? _localProfile;
  HealthProfile _profile = const HealthProfile();
  List<WeightMeasurement> _measurements = [];
  _ChartRange _range = _ChartRange.month;
  _MeasurementSort _measurementSort = _MeasurementSort.date;
  bool _measurementSortAscending = false;
  bool _measurementsExpanded = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _measurementScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final localProfile = await _store.activeLocalProfile();
    final profile = await _store.loadProfile(localProfile.id);
    final measurements = await _store.loadMeasurements(localProfile.id);
    if (!mounted) return;
    setState(() {
      _localProfile = localProfile;
      _profile = profile;
      _measurements = measurements;
      _loading = false;
    });
  }

  Future<void> _saveMeasurements() async {
    _measurements.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    await _store.saveMeasurements(_measurements, _localProfile?.id);
    if (mounted) setState(() {});
  }

  List<WeightMeasurement> get _sortedMeasurements {
    final values = List<WeightMeasurement>.of(_measurements);
    values.sort((a, b) {
      final comparison = switch (_measurementSort) {
        _MeasurementSort.date => a.measuredAt.compareTo(b.measuredAt),
        _MeasurementSort.weight => a.weightKg.compareTo(b.weightKg),
        _MeasurementSort.note =>
          (a.note ?? '').toLowerCase().compareTo((b.note ?? '').toLowerCase()),
      };
      return _measurementSortAscending ? comparison : -comparison;
    });
    return values;
  }

  void _sortMeasurements(_MeasurementSort sort) {
    setState(() {
      if (_measurementSort == sort) {
        _measurementSortAscending = !_measurementSortAscending;
      } else {
        _measurementSort = sort;
        _measurementSortAscending = true;
      }
    });
    if (_measurementScrollController.hasClients) {
      _measurementScrollController.jumpTo(0);
    }
  }

  double _displayWeight(double kg) =>
      _profile.unitSystem == HealthUnitSystem.metric ? kg : kg * 2.2046226218;

  double _toKg(double displayed) =>
      _profile.unitSystem == HealthUnitSystem.metric
          ? displayed
          : displayed / 2.2046226218;

  String get _weightUnit =>
      _profile.unitSystem == HealthUnitSystem.metric ? 'kg' : 'lb';

  String get _profileSummary {
    final values = <String>[];
    if (_profile.birthYear != null) values.add('Born ${_profile.birthYear}');
    if (_profile.heightCm != null) {
      values.add('${_profile.heightCm!.toStringAsFixed(0)} cm');
    }
    if (_profile.sex != HealthSex.unspecified) values.add(_profile.sex.name);
    return values.isEmpty
        ? 'Complete your profile for BMI and better estimates.'
        : values.join(' · ');
  }

  Future<void> _editMeasurement([WeightMeasurement? existing]) async {
    final now = existing?.measuredAt ?? DateTime.now();
    final weightController = TextEditingController(
      text: existing == null
          ? ''
          : _displayWeight(existing.weightKg).toStringAsFixed(1),
    );
    final timestampController = TextEditingController(
      text: _formatDateTime(now),
    );
    final noteController = TextEditingController(text: existing?.note ?? '');
    var selected = now;
    String? timestampError;
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
                TextField(
                  controller: timestampController,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Timestamp',
                    hintText: 'DD.MM.YYYY HH:MM',
                    helperText: 'Type the timestamp or use the date/time picker.',
                    errorText: timestampError,
                    suffixIcon: IconButton(
                      tooltip: 'Choose date and time',
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () async {
                        final typed = _parseDateTime(timestampController.text);
                        final initial = typed ?? selected;
                        final date = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (date == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(initial),
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
                          timestampController.text = _formatDateTime(selected);
                          timestampError = null;
                        });
                      },
                    ),
                  ),
                  onChanged: (_) {
                    if (timestampError != null) {
                      setDialogState(() => timestampError = null);
                    }
                  },
                ),
                const SizedBox(height: 12),
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

                final parsedTimestamp =
                    _parseDateTime(timestampController.text.trim());
                if (parsedTimestamp == null) {
                  setDialogState(() {
                    timestampError = 'Use DD.MM.YYYY HH:MM';
                  });
                  return;
                }
                final maxTimestamp =
                    DateTime.now().add(const Duration(days: 1));
                if (parsedTimestamp.isBefore(DateTime(2000)) ||
                    parsedTimestamp.isAfter(maxTimestamp)) {
                  setDialogState(() {
                    timestampError = 'Choose a date between 2000 and tomorrow.';
                  });
                  return;
                }
                selected = parsedTimestamp;
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final displayed =
        double.parse(weightController.text.trim().replaceAll(',', '.'));
    final measurement = WeightMeasurement(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      weightKg: _toKg(displayed),
      measuredAt: selected,
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );
    final index =
        _measurements.indexWhere((value) => value.id == measurement.id);
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
        content: Text(
          '${_displayWeight(value.weightKg).toStringAsFixed(1)} $_weightUnit · ${_formatDateTime(value.measuredAt)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _measurements.removeWhere((item) => item.id == value.id);
    await _saveMeasurements();
  }

  Future<void> _editProfile() async {
    final localProfile = _localProfile ?? await _store.activeLocalProfile();
    if (!mounted) return;
    final result = await showProfileEditorDialog(
      context,
      title: 'Edit profile',
      initialName: localProfile.name,
      initialHealth: _profile,
    );
    if (result == null) return;
    await _store.renameLocalProfile(localProfile.id, result.name);
    await _store.saveProfile(result.health, localProfile.id);
    await _load();
  }

  Future<void> _exportData() async {
    final payload = jsonEncode({
      'schemaVersion': 1,
      'profileName': _localProfile?.name,
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health data exported.')),
      );
    }
  }

  Future<void> _importData() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: kIsWeb,
    );
    if (picked == null) return;
    final file = picked.files.single;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) return;
    var skipped = 0;
    final imported = <WeightMeasurement>[];
    try {
      final decoded = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(bytes)) as Map,
      );
      for (final raw in (decoded['measurements'] as List? ?? const [])) {
        try {
          final value = WeightMeasurement.fromJson(
            Map<String, dynamic>.from(raw as Map),
          );
          if (value.weightKg <= 0 || value.weightKg >= 500) {
            skipped++;
          } else {
            imported.add(value);
          }
        } catch (_) {
          skipped++;
        }
      }
      final conflicts = imported
          .where(
            (incoming) => _measurements.any(
              (current) =>
                  current.measuredAt.toUtc() == incoming.measuredAt.toUtc(),
            ),
          )
          .length;
      var overwrite = true;
      if (conflicts > 0 && mounted) {
        overwrite = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('$conflicts timestamp conflicts'),
                content: const Text(
                  'Overwrite existing measurements with the imported values, or skip conflicts?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Skip'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Overwrite'),
                  ),
                ],
              ),
            ) ??
            true;
      }
      for (final incoming in imported) {
        final index = _measurements.indexWhere(
          (current) =>
              current.measuredAt.toUtc() == incoming.measuredAt.toUtc(),
        );
        if (index >= 0) {
          if (overwrite) _measurements[index] = incoming;
        } else {
          _measurements.add(incoming);
        }
      }
      await _saveMeasurements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${imported.length} measurements${skipped > 0 ? '; skipped $skipped invalid rows' : ''}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $error')),
        );
      }
    }
  }

  Future<void> _clearMeasurements() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all measurements?'),
        content: const Text(
          'Your profile details will be kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clearMeasurements(_localProfile?.id);
    setState(() => _measurements = []);
  }

  Widget _measurementHeaderCell(
    String label,
    _MeasurementSort sort, {
    int flex = 1,
  }) {
    final selected = _measurementSort == sort;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _sortMeasurements(sort),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                Icon(
                  _measurementSortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _measurementTable() {
    final values = _sortedMeasurements;
    const rowHeight = 56.0;
    final visibleRows = math.min(5, values.length);
    final showScrollbar = values.length > 5;
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              _measurementHeaderCell(
                'Date',
                _MeasurementSort.date,
                flex: 2,
              ),
              _measurementHeaderCell(
                'Weight',
                _MeasurementSort.weight,
              ),
              _measurementHeaderCell(
                'Note',
                _MeasurementSort.note,
                flex: 2,
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        SizedBox(
          height: visibleRows * rowHeight,
          child: RawScrollbar(
            controller: _measurementScrollController,
            thumbVisibility: showScrollbar,
            trackVisibility: showScrollbar,
            thickness: 8,
            radius: const Radius.circular(8),
            trackRadius: const Radius.circular(8),
            thumbColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            trackColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.7),
            mainAxisMargin: 6,
            crossAxisMargin: 4,
            child: Padding(
              padding: EdgeInsets.only(right: showScrollbar ? 14 : 0),
              child: ListView.builder(
                controller: _measurementScrollController,
                primary: false,
                itemExtent: rowHeight,
                itemCount: values.length,
                itemBuilder: (context, index) {
                  final value = values[index];
                  return InkWell(
                    onTap: () => _editMeasurement(value),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                _formatDateTime(value.measuredAt),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${_displayWeight(value.weightKg).toStringAsFixed(1)} $_weightUnit',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                value.note ?? '—',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: IconButton(
                              tooltip: 'Delete measurement',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteMeasurement(value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final daily = HealthAnalytics.dailyAverages(_measurements);
    final latest = _measurements.isEmpty ? null : _measurements.first;
    final bmi = HealthAnalytics.bmi(_profile.heightCm, latest?.weightKg);
    final forecasts = HealthAnalytics.forecasts(daily);
    final cutoff = DateTime.now().subtract(
      Duration(
        days: switch (_range) {
          _ChartRange.week => 7,
          _ChartRange.month => 30,
          _ChartRange.quarter => 90,
          _ChartRange.year => 365,
        },
      ),
    );
    final visible =
        daily.where((point) => !point.day.isBefore(cutoff)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _localProfile == null ? 'Health' : 'Health · ${_localProfile!.name}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'import') _importData();
              if (value == 'export') _exportData();
              if (value == 'clear') _clearMeasurements();
            },
            itemBuilder: (_) => const [
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
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current weight',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  latest == null
                                      ? '—'
                                      : '${_displayWeight(latest.weightKg).toStringAsFixed(1)} $_weightUnit',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                if (latest != null)
                                  Text(_formatDateTime(latest.measuredAt)),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _editMeasurement(),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Add weight'),
                          ),
                        ],
                      ),
                    ),
                    if (bmi != null) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                        child: _BmiBar(bmi: bmi),
                      ),
                    ],
                    const Divider(height: 1),
                    InkWell(
                      onTap: _measurements.isEmpty
                          ? null
                          : () => setState(
                                () => _measurementsExpanded =
                                    !_measurementsExpanded,
                              ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Measurements (${_measurements.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_measurements.isEmpty)
                              Text(
                                'No data',
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            else
                              AnimatedRotation(
                                turns: _measurementsExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: const Icon(Icons.expand_more),
                              ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: _measurementsExpanded && _measurements.isNotEmpty
                          ? Column(
                              children: [
                                const Divider(height: 1),
                                _measurementTable(),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Weight trend',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          SegmentedButton<_ChartRange>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: _ChartRange.week,
                                label: Text('W'),
                              ),
                              ButtonSegment(
                                value: _ChartRange.month,
                                label: Text('M'),
                              ),
                              ButtonSegment(
                                value: _ChartRange.quarter,
                                label: Text('Q'),
                              ),
                              ButtonSegment(
                                value: _ChartRange.year,
                                label: Text('Y'),
                              ),
                            ],
                            selected: {_range},
                            onSelectionChanged: (value) =>
                                setState(() => _range = value.first),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 220,
                        child: visible.length < 2
                            ? const Center(
                                child: Text(
                                  'Add measurements on different days to see your trend.',
                                ),
                              )
                            : CustomPaint(
                                painter: _WeightChartPainter(
                                  visible,
                                  Theme.of(context).colorScheme,
                                ),
                              ),
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
                            Text(
                              'Forecast',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Add weight measurements regularly. AnhPT will show a forecast only when there is enough consistent data.',
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'If your current weight trend continues',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            for (final forecast in forecasts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${forecast.targetDate.difference(DateTime.now()).inDays < 15 ? 'Next week' : 'Next month'}: ${_displayWeight(forecast.lowKg).toStringAsFixed(1)}–${_displayWeight(forecast.highKg).toStringAsFixed(1)} $_weightUnit',
                                ),
                              ),
                            const Text(
                              'Forecasts describe a trend, not the effect of exercise alone.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BmiBar extends StatelessWidget {
  final double bmi;
  const _BmiBar({required this.bmi});

  @override
  Widget build(BuildContext context) {
    final normalized = ((bmi - 15) / 25).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BMI ${bmi.toStringAsFixed(1)} · ${HealthAnalytics.bmiLabel(bmi)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 24,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 7,
                  child: Row(
                    children: [
                      Expanded(child: _RangeColor(Colors.orange)),
                      Expanded(flex: 2, child: _RangeColor(Colors.green)),
                      Expanded(child: _RangeColor(Colors.amber)),
                      Expanded(child: _RangeColor(Colors.red)),
                    ],
                  ),
                ),
                Positioned(
                  left: math.max(
                    0,
                    math.min(
                      constraints.maxWidth - 20,
                      constraints.maxWidth * normalized - 10,
                    ),
                  ),
                  top: 0,
                  child: const Icon(Icons.arrow_drop_down, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
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
    final line = Paint()
      ..color = scheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final dot = Paint()
      ..color = scheme.primary
      ..style = PaintingStyle.fill;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x =
          size.width * point.day.difference(first).inDays / totalDays;
      final y = size.height -
          16 -
          ((point.averageKg - minValue) / spread) * (size.height - 32);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, dot);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.scheme != scheme;
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

DateTime? _parseDateTime(String value) {
  final match = RegExp(
    r'^(\d{1,2})\.(\d{1,2})\.(\d{4})\s+(\d{1,2}):(\d{2})$',
  ).firstMatch(value.trim());
  if (match == null) return null;

  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  final hour = int.tryParse(match.group(4)!);
  final minute = int.tryParse(match.group(5)!);
  if (day == null ||
      month == null ||
      year == null ||
      hour == null ||
      minute == null ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }

  final parsed = DateTime(year, month, day, hour, minute);
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      parsed.hour != hour ||
      parsed.minute != minute) {
    return null;
  }
  return parsed;
}
