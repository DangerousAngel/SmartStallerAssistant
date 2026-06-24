import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:rxdart/rxdart.dart';
import 'build_content.dart';
import 'package:student_assistance_app/services/audio_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Records Grid View Content
Widget buildRecordsContent(
  BuildContext context,
  List<Map<String, dynamic>> timetable,
  List<Map<String, dynamic>> records,
  String? selectedSubject,
  TabController tabController,
  Function(String) onSubjectSelected,
  Function(String) openSubjectRecords,
) {
  final l10n = AppLocalizations.of(context)!;
  final uniqueSubjects = timetable
      .map((s) => s['subject'] as String?)
      .where((s) => s != null)
      .toSet()
      .toList();

  return uniqueSubjects.isEmpty
      ? Center(child: Text(l10n.noSubjectsFound))
      : GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: uniqueSubjects.length,
          itemBuilder: (context, index) {
            final subjectName = uniqueSubjects[index]!;
            final subjectRecords = records
                .where((record) =>
                    record['subject'] == subjectName &&
                    record['filePath'] != null)
                .toList();

            return _buildSubjectCard(
              context: context,
              title: subjectName,
              itemCount: subjectRecords.length,
              icon: Icons.audio_file,
              selectedSubject: selectedSubject,
              tabController: tabController,
              onTap: () {
                onSubjectSelected(subjectName);
                openSubjectRecords(subjectName);
              },
            );
          },
        );
}

Widget _buildSubjectCard({
  required BuildContext context,
  required String title,
  required int itemCount,
  required IconData icon,
  required String? selectedSubject,
  required TabController tabController,
  required VoidCallback onTap,
}) {
  final l10n = AppLocalizations.of(context)!;
  final isSelected = selectedSubject == title;
  return Card(
    elevation: 3,
    color: isSelected
        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
        : null,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(l10n.ofrecords(itemCount),
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    ),
  );
}

// Subject Records Screen
Widget buildSubjectRecordsScreen({
  required BuildContext context,
  required String subject,
  required List<Map<String, dynamic>> records,
  required AudioService audioServicec,
  required VoidCallback onStartRecording,
  required Future<Map<String, dynamic>?> Function() onStopRecording,
  required VoidCallback onPauseRecording,
  required VoidCallback onResumeRecording,
  required bool isRecording,
  required bool isPaused,
  required Function(int id) onDeleteRecord,
  required Function(List<int> ids) onShareRecords,
}) {
  return _SubjectRecordsScreen(
    subject: subject,
    records: records,
    audioService: audioServicec,
    onStartRecording: onStartRecording,
    onStopRecording: onStopRecording,
    onPauseRecording: onPauseRecording,
    onResumeRecording: onResumeRecording,
    isRecording: isRecording,
    isPaused: isPaused,
    onDeleteRecord: onDeleteRecord,
    onShareRecords: onShareRecords,
  );
}

class _SubjectRecordsScreen extends StatefulWidget {
  final String subject;
  final List<Map<String, dynamic>> records;
  final AudioService audioService;
  final VoidCallback onStartRecording;
  final Future<Map<String, dynamic>?> Function() onStopRecording;
  final VoidCallback onPauseRecording;
  final VoidCallback onResumeRecording;
  final bool isRecording;
  final bool isPaused;
  final Function(int id) onDeleteRecord;
  final Function(List<int> ids) onShareRecords;

  const _SubjectRecordsScreen({
    Key? key,
    required this.subject,
    required this.records,
    required this.audioService,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onPauseRecording,
    required this.onResumeRecording,
    required this.isRecording,
    required this.isPaused,
    required this.onDeleteRecord,
    required this.onShareRecords,
  }) : super(key: key);

  @override
  State<_SubjectRecordsScreen> createState() => __SubjectRecordsScreenState();
}

class __SubjectRecordsScreenState extends State<_SubjectRecordsScreen> {
  final Set<int> _selectedIds = {};
  bool _isSelectionMode = false;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  String? _currentlyPlayingPath;
  bool _isPlaying = false;
  bool _isRecording = false;
  bool _isPaused = false;
  late List<Map<String, dynamic>> _localRecords;

  @override
  void initState() {
    super.initState();
    _localRecords = List.from(widget.records);
    _localRecords
        .sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

    _playerStateSubscription =
        widget.audioService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            // Do NOT nullify _currentlyPlayingPath so progress bar stays
            // _currentlyPlayingPath = null;
            _isPlaying = false;
          }
        });
      }
    });
    _isRecording = widget.isRecording;
    _isPaused = widget.isPaused;
  }

  @override
  void didUpdateWidget(covariant _SubjectRecordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != oldWidget.records) {
      _localRecords = List.from(widget.records);
      _localRecords.sort(
          (a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
    }
    if (widget.isRecording != _isRecording) {
      setState(() => _isRecording = widget.isRecording);
    }
    if (widget.isPaused != _isPaused) {
      setState(() => _isPaused = widget.isPaused);
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();

    // ✅ Stop audio when leaving the screen
    widget.audioService.pausePlayback();
    widget.audioService.seek(Duration.zero);
    // Or use stop() if you add it in AudioServicec:
    // widget.audioService.stopPlayback();

    super.dispose();
  }

  void _onPlayTap(String filePath) {
    if (_currentlyPlayingPath == filePath && _isPlaying) {
      widget.audioService.pausePlayback();
    } else {
      setState(() => _currentlyPlayingPath = filePath);
      widget.audioService.playRecording(filePath);
    }
  }

  void _toggleSelection(int id) => setState(() {
        _selectedIds.contains(id)
            ? _selectedIds.remove(id)
            : _selectedIds.add(id);
        _isSelectionMode = _selectedIds.isNotEmpty;
      });

  void _clearSelection() => setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });

  Future<void> _deleteSelected() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.confirmDelete),
            content: Text(l10n.deleteNItems(_selectedIds.length)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel)),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.delete)),
            ],
          ),
        ) ??
        false;
    if (confirmed == true) {
      for (int id in _selectedIds.toList()) {
        final record = _localRecords.firstWhere(
          (rec) => rec['id'] == id,
          orElse: () => {},
        );
        final filePath = record['filePath'] as String?;
        if (filePath != null &&
            _currentlyPlayingPath == filePath &&
            _isPlaying) {
          await widget.audioService.pausePlayback();
          setState(() {
            _currentlyPlayingPath = null;
            _isPlaying = false;
          });
        }
        await widget.onDeleteRecord(id);
        _localRecords.removeWhere((rec) => rec['id'] == id);
      }
      _clearSelection();
      if (mounted) {
        if (_localRecords.isEmpty) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.deletedNItems(_selectedIds.length))));
      }
    }
  }

  void _shareSelected() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedIds.isEmpty) return;
    final files = _localRecords
        .where((record) =>
            _selectedIds.contains(record['id']) && record['filePath'] != null)
        .map((record) => XFile(record['filePath'] as String))
        .toList();
    if (files.isNotEmpty) {
      try {
        await Share.shareXFiles(files,
            text: '${l10n.records} from ${widget.subject}');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${l10n.errorSavingRecording(e.toString())}')));
        }
      }
    }
    _clearSelection();
  }

  void _handleStartRecording() {
    widget.onStartRecording();
    setState(() {
      _isRecording = true;
      _isPaused = false;
    });
  }

  void _handlePauseRecording() {
    widget.onPauseRecording();
    setState(() => _isPaused = true);
  }

  void _handleResumeRecording() {
    widget.onResumeRecording();
    setState(() => _isPaused = false);
  }

  Future<void> _handleStopRecording() async {
    final newRecord = await widget.onStopRecording();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      if (newRecord != null) {
        _localRecords.insert(0, newRecord); // newest first
      }
    });
  }

  // 🔹 Stream for progress bar
  Stream<DurationState> get _durationStateStream =>
      Rx.combineLatest2<Duration, PlaybackEvent, DurationState>(
        widget.audioService.player.positionStream,
        widget.audioService.player.playbackEventStream,
        (position, event) => DurationState(
          position: position,
          buffered: event.bufferedPosition,
          total: event.duration,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(l10n.itemsSelected(_selectedIds.length))
            : Text('${widget.subject} ${l10n.records}'),
        actions: _isSelectionMode
            ? [
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSelection,
                    tooltip: l10n.cancel),
                IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: _shareSelected,
                    tooltip: '${l10n.share} ${l10n.selected}'),
                IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _deleteSelected,
                    tooltip: '${l10n.delete} ${l10n.selected}'),
              ]
            : null,
      ),
      body: _localRecords.isEmpty && !_isRecording
          ? Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.audio_file, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('${l10n.noRecordsYet} ${widget.subject}.'),
              ],
            ))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _localRecords.length,
              itemBuilder: (context, index) {
                final record = _localRecords[index];
                final filePath = record['filePath'] as String?;
                final id = record['id'] as int?;
                final isSelected = id != null && _selectedIds.contains(id);
                final isCurrentlyPlaying =
                    _currentlyPlayingPath == filePath && _isPlaying;

                if (filePath == null) {
                  return const ListTile(
                      leading: Icon(Icons.error), title: Text('Invalid file'));
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Column(
                    children: [
                      ListTile(
                        leading: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Color.fromRGBO(210, 181, 138, 1))
                            : const Icon(Icons.audio_file),
                        title: Text(
                            '${l10n.record} ${_localRecords.length - index}'),
                        subtitle: Text(record['createdAt'] != null
                            ? DateTime.parse(record['createdAt'])
                                .toLocal()
                                .toString()
                            : ''),
                        trailing: _isSelectionMode
                            ? null
                            : IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, animation) =>
                                      ScaleTransition(
                                          scale: animation, child: child),
                                  child: Icon(
                                    isCurrentlyPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                    key: ValueKey(isCurrentlyPlaying),
                                    size: 30,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                onPressed: () => _onPlayTap(filePath),
                              ),
                        onTap: id != null
                            ? (_isSelectionMode
                                ? () => _toggleSelection(id)
                                : () => _onPlayTap(filePath))
                            : null,
                        onLongPress:
                            id != null ? () => _toggleSelection(id) : null,
                        tileColor: isSelected
                            ? Color.fromRGBO(210, 181, 138, 1).withOpacity(0.1)
                            : null,
                      ),

                      // ✅ Progress bar when playing OR selected/paused
                      if (_currentlyPlayingPath == filePath)
                        StreamBuilder<DurationState>(
                          stream: _durationStateStream,
                          builder: (context, snapshot) {
                            final durationState = snapshot.data;
                            final position =
                                durationState?.position ?? Duration.zero;
                            final total = durationState?.total ?? Duration.zero;

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: ProgressBar(
                                progress: position,
                                buffered:
                                    durationState?.buffered ?? Duration.zero,
                                total: total ?? Duration.zero,
                                onSeek: (duration) {
                                  widget.audioService.player.seek(duration);
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: _isSelectionMode
          ? null
          : BuildContent.buildRecordFab(
              heroTag: 'subject_records_fab',
              context: context,
              isRecording: _isRecording,
              isPaused: _isPaused,
              onStart: _handleStartRecording,
              onPause: _handlePauseRecording,
              onResume: _handleResumeRecording,
              onStop: _handleStopRecording,
              onTakePhoto: () {},
              onStartRecord: () {},
            ),
    );
  }
}

// 🔹 Helper for duration state
class DurationState {
  final Duration position;
  final Duration buffered;
  final Duration? total;

  DurationState({
    required this.position,
    required this.buffered,
    required this.total,
  });
}
