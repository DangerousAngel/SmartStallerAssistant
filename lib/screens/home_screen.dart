import 'package:flutter/material.dart';
import 'package:student_assistance_app/services/database_service.dart';
import 'package:student_assistance_app/widgets/folder_card.dart';
import 'package:student_assistance_app/widgets/quick_actions.dart';
import 'package:student_assistance_app/widgets/upcoming_lectures.dart';
import 'package:student_assistance_app/widgets/clock.dart';
import 'package:student_assistance_app/screens/folder_detail_screen.dart';
import 'package:student_assistance_app/screens/timetable_screen.dart';
import 'package:student_assistance_app/screens/lectures_screen.dart';
import 'package:student_assistance_app/screens/ai_chat_screen.dart';
import 'package:student_assistance_app/screens/todo_screen.dart';
import 'package:student_assistance_app/widgets/todo_preview.dart';
import 'package:student_assistance_app/widgets/subject_selection_bottom_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:student_assistance_app/services/file_storage_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:student_assistance_app/widgets/gradient_app_bar.dart';

class HomeScreen extends StatefulWidget {
  final DatabaseService databaseService;

  const HomeScreen({super.key, required this.databaseService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _timetable = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final folders = await widget.databaseService.getFolders();
    final timetable = await widget.databaseService.getTimetable();

    if (mounted) {
      setState(() {
        _folders = folders;
        _timetable = timetable;
        _isLoading = false;
      });
    }
  }

  void _navigateToTodoScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TodoScreen(databaseService: widget.databaseService),
      ),
    );
    // Refresh the preview when returning from To-Do screen
    _loadData();
  }

  Future<void> _takePhotoForSubject(String subject) async {
    final l10n = AppLocalizations.of(context)!;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      try {
        final fileName =
            '${subject}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath =
            await FileStorageService.savePhoto(File(image.path), fileName);
        await widget.databaseService.insertMedia({
          'title': subject,
          'type': 'photo',
          'filePath': savedPath,
          'subject': subject,
          'createdAt': DateTime.now().toIso8601String(),
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.photoSavedFor(subject))));
        _loadData();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.errorSavingPhoto(e.toString()))));
      }
    }
  }

  void _navigateToLecturesForRecording() {
    SubjectSelectionBottomSheet.show(
      context: context,
      timetable: _timetable,
      databaseService: widget.databaseService,
      isPhoto: false,
      onSubjectSelected: (subject) async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LecturesScreen(
              databaseService: widget.databaseService,
              initialTab: 1,
              initialSubject: subject,
              startActionImmediately: true,
            ),
          ),
        );
        _loadData();
      },
    );
  }

  void _addFolder() async {
    // FIX: Get l10n from the valid HomeScreen context BEFORE showing the dialog
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FolderDialog(l10n: l10n), // Pass l10n to the dialog
    );

    if (result != null) {
      await widget.databaseService.insertFolder(result);
      _loadData();
    }
  }

  void _editFolder(Map<String, dynamic> folder) async {
    // FIX: Get l10n from the valid HomeScreen context BEFORE showing the dialog
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FolderDialog(
          initialData: folder, l10n: l10n), // Pass l10n to the dialog
    );

    if (result != null) {
      await widget.databaseService.updateFolder(folder['id'], result);
      _loadData();
    }
  }

  void _navigateToNewNote() async {
    if (_folders.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FolderDetailScreen(
            folder: _folders.last,
            databaseService: widget.databaseService,
          ),
        ),
      );
      _loadData();
    } else {
      _showCreateFolderDialog();
    }
  }

  void _navigateToTimetable() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimetableScreen(
          databaseService: widget.databaseService,
          hideFab: true,
        ),
      ),
    );
    _loadData();
  }

  void _showCreateFolderDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.noFoldersYet),
        content: Text(l10n.createFirstFolder),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addFolder();
            },
            child: Text(l10n.addFolder),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: GradientAppBar(
        title: Text(l10n.studentAssistant),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/ic_launcher_foreground.png',
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.scatter_plot_sharp),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AIChatScreen()),
              );
            },
            tooltip: l10n.aiAssistant,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TimeWidget(),
                  QuickActions(
                    onNewNote: _navigateToNewNote,
                    onTimetable: _navigateToTimetable,
                    onRecord: _navigateToLecturesForRecording,
                    onTakePhotoForSubject: _takePhotoForSubject,
                    timetable: _timetable,
                    databaseService: widget.databaseService,
                  ),
                  const SizedBox(height: 24),
                  UpcomingLectures(databaseService: widget.databaseService),
                  const SizedBox(height: 24),
                  // Add the To-Do preview here
                  TodoPreview(
                    databaseService: widget.databaseService,
                    onTap: _navigateToTodoScreen,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.myFolders,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addFolder,
                        tooltip: l10n.addFolder,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _folders.isEmpty
                      ? Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noFoldersYet,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.createFirstFolder,
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _folders.length,
                          itemBuilder: (context, index) {
                            return FolderCard(
                              folder: _folders[index],
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FolderDetailScreen(
                                      folder: _folders[index],
                                      databaseService: widget.databaseService,
                                    ),
                                  ),
                                );
                                _loadData();
                              },
                              onEdit: () => _editFolder(_folders[index]),
                              onDelete: () async {
                                await widget.databaseService
                                    .deleteFolder(_folders[index]['id']);
                                _loadData();
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AIChatScreen()),
            );
          },
          child: const Icon(
            Icons.scatter_plot_sharp,
            color: Colors.black,
          ),
          backgroundColor: Color.fromRGBO(210, 181, 138, 1)),
    );
  }
}

class FolderDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final AppLocalizations l10n; // FIX: Receive the l10n instance

  const FolderDialog({
    super.key,
    this.initialData,
    required this.l10n,
  });

  @override
  State<FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<FolderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late Color _selectedColor;

  final List<Color> _colorOptions = [
    const Color(0xFF224A60), // Deep Blue (Primary)
    const Color(0xFFFFD700), // Gold (Accent)
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'];
      _selectedColor = Color(widget.initialData!['color']);
    } else {
      _selectedColor = _colorOptions.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialData != null;
    final l10n = widget.l10n;

    return AlertDialog(
      title: Text(isEditing ? l10n.editFolder : l10n.createNewFolder),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                textDirection: l10n.localeName == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.folderName,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.pleaseEnterTitle;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(l10n.chooseColor),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorOptions.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _selectedColor.value == color.value
                            ? Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                                width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final result = {
                'name': _nameController.text,
                'color': _selectedColor.value,
              };
              if (!isEditing) {
                result['createdAt'] = DateTime.now().toIso8601String();
              }
              Navigator.pop(context, result);
            }
          },
          child: Text(isEditing ? l10n.save : l10n.create),
        ),
      ],
    );
  }
}
