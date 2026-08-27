import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../models/background_music.dart';
import '../services/music_library_service.dart';

class MusicLibraryScreen extends StatefulWidget {
  final AppController controller;
  const MusicLibraryScreen({super.key, required this.controller});
  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  final AudioPlayer _preview = AudioPlayer();
  String _mood = 'All';
  String? _playing;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  bool _importing = false;
  String? _importStatus;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _preview.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _positionSubscription = _preview.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _durationSubscription = _preview.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
  }

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _importStatus = 'Opening Windows file picker…';
    });
    try {
      final imported = await widget.controller.importMusicTrack();
      if (!mounted) return;
      setState(() {
        _importStatus = imported
            ? 'Track imported and copied to the local music library.'
            : 'Import cancelled. No file was selected.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _importStatus =
          'Import failed. Choose a supported local audio file and try again. Details: $error');
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _play(MusicTrack track) async {
    try {
      await _preview.stop();
      setState(() {
        _playing = track.id;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
      await _preview.play(track.bundled
          ? AssetSource(track.source)
          : DeviceFileSource(track.source));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Track file is missing or cannot be played.')));
      }
    }
  }

  Future<void> _pause() => _preview.pause();
  Future<void> _resume() => _preview.resume();

  Future<void> _stop() async {
    await _preview.stop();
    if (mounted) {
      setState(() {
        _position = Duration.zero;
        _playerState = PlayerState.stopped;
      });
    }
  }

  Future<void> _seek(double milliseconds) =>
      _preview.seek(Duration(milliseconds: milliseconds.round()));

  String _time(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _edit(MusicTrack track) async {
    final name = TextEditingController(text: track.name);
    final mood = TextEditingController(text: track.mood);
    final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Edit track'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: mood,
                      decoration: const InputDecoration(labelText: 'Mood'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save'))
                ]));
    if (save == true) {
      await widget.controller.updateMusicTrack(MusicTrack(
          id: track.id,
          name: name.text.trim().isEmpty ? track.name : name.text.trim(),
          mood: mood.text.trim(),
          source: track.source,
          bundled: false,
          createdAt: track.createdAt));
    }
  }

  Future<void> _delete(MusicTrack track) async {
    final affected = widget.controller.workoutsUsingTrack(track.id).length;
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Delete “${track.name}”?'),
                content: Text(affected == 0
                    ? 'The local file will be deleted.'
                    : '$affected workout assignment(s) will be cleared and the local file deleted.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'))
                ]));
    if (ok == true) {
      if (_playing == track.id) {
        await _stop();
        _playing = null;
      }
      await widget.controller.deleteMusicTrack(track.id);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Music Library')),
      floatingActionButton: FloatingActionButton.extended(
          tooltip: MusicLibraryService.supportedFormatsLabel,
          onPressed: _importing ? null : _import,
          icon: _importing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.library_music),
          label: Text(_importing ? 'Importing…' : 'Import')),
      body: AnimatedBuilder(
          animation: widget.controller,
          builder: (_, __) {
            final moods = {
              'All',
              ...widget.controller.musicTracks
                  .map((e) => e.mood)
                  .where((e) => e.isNotEmpty)
            }.toList();
            final tracks = widget.controller.musicTracks
                .where((e) => _mood == 'All' || e.mood == _mood)
                .toList();
            final activeTrack = widget.controller.musicTrackById(_playing);
            return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                children: [
                  if (_importStatus != null) ...[
                    Card(
                      child: ListTile(
                        leading: Icon(_importing
                            ? Icons.hourglass_top
                            : Icons.info_outline),
                        title: Text(_importStatus!),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (activeTrack != null) ...[
                    Card(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: .45),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.graphic_eq),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Now previewing',
                                        style: TextStyle(fontSize: 12)),
                                    Text(activeTrack.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                              Text('${_time(_position)} / ${_time(_duration)}'),
                            ]),
                            Slider(
                              value: _duration.inMilliseconds <= 0
                                  ? 0
                                  : _position.inMilliseconds
                                      .clamp(0, _duration.inMilliseconds)
                                      .toDouble(),
                              max: _duration.inMilliseconds <= 0
                                  ? 1
                                  : _duration.inMilliseconds.toDouble(),
                              onChanged:
                                  _duration.inMilliseconds <= 0 ? null : _seek,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  tooltip: _playerState == PlayerState.playing
                                      ? 'Pause'
                                      : 'Play / resume',
                                  onPressed: _playerState == PlayerState.playing
                                      ? _pause
                                      : _playerState == PlayerState.paused
                                          ? _resume
                                          : () => _play(activeTrack),
                                  icon: Icon(_playerState == PlayerState.playing
                                      ? Icons.pause
                                      : Icons.play_arrow),
                                ),
                                const SizedBox(width: 12),
                                IconButton.outlined(
                                  tooltip: 'Stop',
                                  onPressed: _stop,
                                  icon: const Icon(Icons.stop),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  DropdownButton<String>(
                      value: moods.contains(_mood) ? _mood : 'All',
                      items: moods
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _mood = value ?? 'All')),
                  for (final track in tracks)
                    Card(
                        child: ListTile(
                            leading: Icon(track.bundled
                                ? Icons.inventory_2_outlined
                                : Icons.audio_file),
                            title: Text(track.name),
                            subtitle: Text(
                                '${track.mood} · ${track.bundled ? 'Bundled' : 'Personal'}'),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                  onPressed: () => _playing == track.id &&
                                          _playerState == PlayerState.playing
                                      ? _pause()
                                      : _playing == track.id &&
                                              _playerState == PlayerState.paused
                                          ? _resume()
                                          : _play(track),
                                  icon: Icon(_playing == track.id &&
                                          _playerState == PlayerState.playing
                                      ? Icons.pause
                                      : Icons.play_arrow),
                                  tooltip: 'Preview'),
                              if (!track.bundled)
                                PopupMenuButton<String>(
                                    onSelected: (value) => value == 'edit'
                                        ? _edit(track)
                                        : _delete(track),
                                    itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Rename / mood')),
                                          PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete'))
                                        ])
                            ])))
                ]);
          }));

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel() ?? Future<void>.value());
    unawaited(_positionSubscription?.cancel() ?? Future<void>.value());
    unawaited(_durationSubscription?.cancel() ?? Future<void>.value());
    unawaited(_preview.dispose());
    super.dispose();
  }
}
