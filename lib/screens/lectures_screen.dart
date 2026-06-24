// lectures_screen.dart
import 'package:flutter/material.dart';
import 'package:student_assistance_app/services/database_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:student_assistance_app/services/audio_service.dart';
import 'package:student_assistance_app/widgets/subject_selection_bottom_sheet.dart';
import 'package:student_assistance_app/services/file_storage_service.dart';
import 'package:student_assistance_app/widgets/build_photos.dart';
import 'package:student_assistance_app/widgets/build_records.dart';
import 'package:student_assistance_app/widgets/build_content.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:student_assistance_app/widgets/gradient_app_bar.dart';

class LecturesScreen extends StatefulWidget {
  final DatabaseService databaseService;
  final int initialTab;
  final String? initialSubject;
  final bool startActionImmediately;

  const LecturesScreen({
    super.key,
    required this.databaseService,
    this.initialTab = 0,
    this.initialSubject,
    this.startActionImmediately = false,
  });

  @override
  State<LecturesScreen> createState() => LecturesScreenState();
}

class LecturesScreenState extends State<LecturesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _timetable = [];
  List<Map<String, dynamic>> _photos = [];
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  final AudioService _audioService = AudioService();

  bool _isRecording = false;
  bool _isPaused = false;
  String? _selectedSubject;
  String? _currentRecordingPath;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);

    _tabController.addListener(_handleTabChange);

    if (widget.initialSubject != null) _selectedSubject = widget.initialSubject;
    _loadData();

    if (widget.startActionImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (widget.initialSubject != null) {
            if (_tabController.index == 1) {
              startRecording(widget.initialSubject!);
            }
          } else {
            _showSubjectSelection(context, _tabController.index == 0);
          }
        }
      });
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging || !_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final timetable = await widget.databaseService.getTimetable();
    final photos = await widget.databaseService.getMediaByType('photo');
    final records = await widget.databaseService.getMediaByType('recording');

    if (mounted)
      setState(() {
        _timetable = timetable;
        _photos = photos;
        _records = records;
        _isLoading = false;
      });
  }

  Future<Map<String, dynamic>?> takePhoto(String subject) async {
    final l10n = AppLocalizations.of(context)!;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      try {
        final fileName =
            '${subject}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath =
            await FileStorageService.savePhoto(File(image.path), fileName);
        final newMedia = {
          'title': subject,
          'type': 'photo',
          'filePath': savedPath,
          'subject': subject,
          'createdAt': DateTime.now().toIso8601String(),
        };
        await widget.databaseService.insertMedia(newMedia);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.photoSavedFor(subject))));
        }
        return newMedia;
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.errorSavingPhoto(e.toString()))));
      }
    }
    return null;
  }

  Future<void> startRecording(String subject) async {
    final path = await _audioService.startRecording();
    if (path != null)
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _selectedSubject = subject;
        _currentRecordingPath = path;
      });
  }

  Future<void> _pauseRecording() async {
    await _audioService.pauseRecording();
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    await _audioService.resumeRecording();
    setState(() => _isPaused = false);
  }

  Future<Map<String, dynamic>?> _stopAndSaveRecording() async {
    final l10n = AppLocalizations.of(context)!;
    if (_currentRecordingPath == null || _selectedSubject == null) return null;
    final subject = _selectedSubject!;

    final path = await _audioService.stopRecording();
    if (path != null) {
      try {
        final fileName =
            '${subject}_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final savedPath =
            await FileStorageService.saveRecording(File(path), fileName);
        final newMedia = {
          'title': subject,
          'type': 'recording',
          'filePath': savedPath,
          'subject': subject,
          'createdAt': DateTime.now().toIso8601String(),
        };
        await widget.databaseService.insertMedia(newMedia);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.recordingSavedFor(subject))));
        }
        setState(() {
          _isRecording = false;
          _isPaused = false;
          _currentRecordingPath = null;
        });
        return newMedia;
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.errorSavingRecording(e.toString()))));
      }
    }
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _currentRecordingPath = null;
    });
    return null;
  }

  Future<void> _deleteMedia(int id) async {
    await widget.databaseService.deleteMedia(id);
    _loadData();
  }

  Future<void> _sharePhotos(List<int> ids) async {}
  Future<void> _shareRecords(List<int> ids) async {}

  void _showSubjectSelection(BuildContext context, bool isPhoto) {
    SubjectSelectionBottomSheet.show(
      context: context,
      timetable: _timetable,
      databaseService: widget.databaseService,
      isPhoto: isPhoto,
      onSubjectSelected: (subject) {
        if (isPhoto)
          takePhoto(subject);
        else
          startRecording(subject);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final Color tabBarForegroundColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: GradientAppBar(
        leading: const Icon(Icons.school),
        title: Text(l10n.lectures),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.secondary,
          labelColor: Theme.of(context).colorScheme.secondary,
          unselectedLabelColor: tabBarForegroundColor.withOpacity(0.6),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 3.0,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          tabs: [
            Tab(icon: const Icon(Icons.photo_library), text: l10n.photoss),
            Tab(icon: const Icon(Icons.audio_file), text: l10n.records),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              children: [
                buildPhotosContent(
                    context,
                    _timetable,
                    _photos,
                    _selectedSubject,
                    _tabController,
                    (subject) => setState(() => _selectedSubject = subject),
                    _openSubjectGallery),
                buildRecordsContent(
                    context,
                    _timetable,
                    _records,
                    _selectedSubject,
                    _tabController,
                    (subject) => setState(() => _selectedSubject = subject),
                    _openSubjectRecords),
              ],
            ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget? _buildFloatingActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    if (_tabController.index == 0) {
      return FloatingActionButton(
        heroTag: 'lectures_screen_photo_fab',
        onPressed: () => _showSubjectSelection(context, true),
        tooltip: l10n.takePhoto,
        child: const Icon(
          Icons.camera_alt,
          color: Colors.black,
        ),
        backgroundColor: Color.fromRGBO(210, 181, 138, 1),
      );
    } else {
      return BuildContent.buildRecordFab(
        heroTag: 'lectures_screen_record_fab',
        context: context,
        isRecording: _isRecording,
        isPaused: _isPaused,
        onStart: () => _showSubjectSelection(context, false),
        onPause: _pauseRecording,
        onResume: _resumeRecording,
        onStop: _stopAndSaveRecording,
        onTakePhoto: () => _showSubjectSelection(context, true),
        onStartRecord: () => _showSubjectSelection(context, false),
      );
    }
  }

  void _openSubjectGallery(String subject) async {
    final subjectPhotos =
        _photos.where((p) => p['subject'] == subject).toList();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => buildSubjectGalleryScreen(
          context: context,
          subject: subject,
          photos: subjectPhotos,
          onTakePhoto: () async {
            final newMedia = await takePhoto(subject);
            return newMedia;
          },
          onDeletePhoto: _deleteMedia,
          onSharePhotos: _sharePhotos,
        ),
      ),
    );
    _loadData();
  }

  void _openSubjectRecords(String subject) async {
    final subjectRecords =
        _records.where((r) => r['subject'] == subject).toList();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => buildSubjectRecordsScreen(
          context: context,
          subject: subject,
          records: subjectRecords,
          audioServicec: _audioService,
          onStartRecording: () => startRecording(subject),
          onStopRecording: _stopAndSaveRecording,
          onPauseRecording: _pauseRecording,
          onResumeRecording: _resumeRecording,
          isRecording: _isRecording && _selectedSubject == subject,
          isPaused: _isPaused,
          onDeleteRecord: _deleteMedia,
          onShareRecords: _shareRecords,
        ),
      ),
    );
    _loadData();
  }
}
