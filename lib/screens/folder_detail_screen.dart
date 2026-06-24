import 'package:flutter/material.dart';
import 'package:student_assistance_app/services/database_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import localization

class FolderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> folder;
  final DatabaseService databaseService;

  const FolderDetailScreen({
    super.key,
    required this.folder,
    required this.databaseService,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final notes = await widget.databaseService.getNotes(widget.folder['id']);
    if (mounted) {
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    }
  }

  void _addNote() async {
    // FIXED: Get l10n instance from the build context before the async gap
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => NoteDialog(
        folderColor: Color(widget.folder['color']),
        l10n: l10n, // Pass it to the dialog
      ),
    );

    if (result != null) {
      await widget.databaseService.insertNote({
        ...result,
        'folderId': widget.folder['id'],
        'createdAt': DateTime.now().toIso8601String(),
      });
      _loadContent();
    }
  }

  void _editNote(Map<String, dynamic> note) async {
    // FIXED: Get l10n instance from the build context before the async gap
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => NoteDialog(
        initialTitle: note['title'],
        initialContent: note['content'],
        folderColor: Color(widget.folder['color']),
        l10n: l10n, // Pass it to the dialog
      ),
    );

    if (result != null) {
      await widget.databaseService.updateNote(
        note['id'],
        {
          'title': result['title'],
          'content': result['content'],
        },
      );
      _loadContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the localization instance for this build context
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder['name']),
        backgroundColor: Color(widget.folder['color']),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Text(l10n.noNotesYet)) // UPDATED: Use localized string
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Dismissible(
                      key: ValueKey(note['id']),
                      direction: Directionality.of(context) == TextDirection.rtl
                          ? DismissDirection.endToStart
                          : DismissDirection.startToEnd,
                      background: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.red,
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) async {
                        await widget.databaseService.deleteNote(note['id']);
                        _loadContent();
                      },
                      child: _NoteCard(
                        note: note,
                        folderColor: Color(widget.folder['color']),
                        onEdit: () => _editNote(note),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        backgroundColor: Color(widget.folder['color']),
        foregroundColor: Colors.white,
        child: const Icon(Icons.note_add),
      ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  final Map<String, dynamic> note;
  final Color folderColor;
  final VoidCallback onEdit;

  const _NoteCard({
    required this.note,
    required this.folderColor,
    required this.onEdit,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final contentColor = isDarkMode
        ? Colors.grey.shade300
        : const Color.fromARGB(255, 61, 61, 61);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.note['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    width: 30,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.edit, size: 20),
                      color: widget.folderColor,
                      onPressed: widget.onEdit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  widget.note['content'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: contentColor),
                ),
                secondChild: Text(
                  widget.note['content'],
                  style: TextStyle(color: contentColor, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteDialog extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final Color folderColor;
  final AppLocalizations l10n; // NEW: Pass the localization instance

  const NoteDialog({
    super.key,
    this.initialTitle,
    this.initialContent,
    required this.folderColor,
    required this.l10n, // NEW: Make it required
  });

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the passed l10n instance
    final l10n = widget.l10n;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: widget.folderColor,
            ),
      ),
      child: AlertDialog(
        title:
            Text(widget.initialTitle == null ? l10n.addNewNote : l10n.editNote),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  textDirection: l10n.localeName == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.title,
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
                TextFormField(
                  controller: _contentController,
                  textDirection: l10n.localeName == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.content, // UPDATED
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.pleaseEnterContent; // UPDATED
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel), // UPDATED
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'title': _titleController.text,
                  'content': _contentController.text,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.folderColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.save), // UPDATED
          ),
        ],
      ),
    );
  }
}
