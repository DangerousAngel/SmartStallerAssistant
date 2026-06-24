import 'package:flutter/material.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Photos Grid View Content
Widget buildPhotosContent(
  BuildContext context,
  List<Map<String, dynamic>> timetable,
  List<Map<String, dynamic>> photos,
  String? selectedSubject,
  TabController tabController,
  Function(String) onSubjectSelected,
  Function(String) openSubjectGallery,
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
            final subjectPhotos = photos
                .where((photo) =>
                    photo['subject'] == subjectName &&
                    photo['filePath'] != null)
                .toList();

            return _buildSubjectCard(
              context,
              subjectName,
              subjectPhotos.length,
              Icons.photo_library,
              selectedSubject,
              tabController,
              () {
                onSubjectSelected(subjectName);
                openSubjectGallery(subjectName);
              },
            );
          },
        );
}

Widget _buildSubjectCard(
  BuildContext context,
  String title,
  int itemCount,
  IconData icon,
  String? selectedSubject,
  TabController tabController,
  VoidCallback onTap,
) {
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
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2),
            const SizedBox(height: 8),
            Text(l10n.ofphotos(itemCount),
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    ),
  );
}

// Subject Gallery Screen
Widget buildSubjectGalleryScreen({
  required BuildContext context,
  required String subject,
  required List<Map<String, dynamic>> photos,
  required Future<Map<String, dynamic>?> Function() onTakePhoto,
  required Function(int id) onDeletePhoto,
  required Function(List<int> ids) onSharePhotos,
}) {
  return _SubjectGalleryScreen(
    subject: subject,
    photos: photos,
    onTakePhoto: onTakePhoto,
    onDeletePhoto: onDeletePhoto,
    onSharePhotos: onSharePhotos,
  );
}

class _SubjectGalleryScreen extends StatefulWidget {
  final String subject;
  final List<Map<String, dynamic>> photos;
  final Future<Map<String, dynamic>?> Function() onTakePhoto;
  final Function(int id) onDeletePhoto;
  final Function(List<int> ids) onSharePhotos;

  const _SubjectGalleryScreen({
    required this.subject,
    required this.photos,
    required this.onTakePhoto,
    required this.onDeletePhoto,
    required this.onSharePhotos,
  });

  @override
  State<_SubjectGalleryScreen> createState() => __SubjectGalleryScreenState();
}

class __SubjectGalleryScreenState extends State<_SubjectGalleryScreen> {
  final Set<int> _selectedIds = {};
  bool _isSelectionMode = false;
  late List<Map<String, dynamic>> _localPhotos;

  @override
  void initState() {
    super.initState();
    _localPhotos = List.from(widget.photos);
  }

  @override
  void didUpdateWidget(covariant _SubjectGalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photos != oldWidget.photos) {
      setState(() => _localPhotos = List.from(widget.photos));
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      _selectedIds.contains(id)
          ? _selectedIds.remove(id)
          : _selectedIds.add(id);
      _isSelectionMode = _selectedIds.isNotEmpty;
    });
  }

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
            ));

    if (confirmed == true) {
      for (int id in _selectedIds.toList()) {
        await widget.onDeletePhoto(id);
        _localPhotos.removeWhere((photo) => photo['id'] == id);
      }
      _clearSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.deletedNItems(_selectedIds.length))));
        if (_localPhotos.isEmpty) Navigator.pop(context);
      }
    }
  }

  void _shareSelected() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedIds.isEmpty) return;
    final files = _localPhotos
        .where((photo) =>
            _selectedIds.contains(photo['id']) && photo['filePath'] != null)
        .map((photo) => XFile(photo['filePath'] as String))
        .toList();

    if (files.isNotEmpty) {
      try {
        await Share.shareXFiles(files,
            text: '${l10n.photoss} from ${widget.subject}');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.errorSavingPhoto(e.toString())}')));
      }
    }
    _clearSelection();
  }

  Future<void> _handleTakePhoto() async {
    final newPhoto = await widget.onTakePhoto();
    if (newPhoto != null && mounted) {
      setState(() => _localPhotos.add(newPhoto));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(l10n.itemsSelected(_selectedIds.length))
            : Text('${widget.subject} ${l10n.photoss}'),
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
      body: _localPhotos.isEmpty
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_library,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('${l10n.noPhotosYet} ${widget.subject}.'),
                  ]),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: _localPhotos.length,
              itemBuilder: (context, index) {
                final photo = _localPhotos[index];
                final filePath = photo['filePath'] as String?;
                final id = photo['id'] as int?;
                final isSelected = id != null && _selectedIds.contains(id);

                if (filePath == null)
                  return const Icon(Icons.error, color: Colors.red);

                return GestureDetector(
                  onTap: _isSelectionMode && id != null
                      ? () => _toggleSelection(id)
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  _PhotoViewerScreen(imagePath: filePath))),
                  onLongPress: id != null ? () => _toggleSelection(id) : null,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(File(filePath), fit: BoxFit.cover),
                    if (isSelected)
                      Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Icon(Icons.check_circle,
                              color: Color.fromRGBO(210, 181, 138, 1),
                              size: 30)),
                  ]),
                );
              },
            ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _handleTakePhoto,
              tooltip: l10n.takePhoto,
              child: const Icon(Icons.camera_alt, color: Colors.black),
              backgroundColor: Color.fromRGBO(210, 181, 138, 1)),
    );
  }
}

class _PhotoViewerScreen extends StatelessWidget {
  final String imagePath;
  const _PhotoViewerScreen({required this.imagePath});

  void _sharePhoto(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Share.shareXFiles([XFile(imagePath)]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorSavingPhoto(e.toString())}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePhoto(context),
            tooltip: '${l10n.share} ${l10n.photo}',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true, // allow drag
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
