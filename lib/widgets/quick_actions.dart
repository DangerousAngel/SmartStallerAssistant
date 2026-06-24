import 'package:flutter/material.dart';
import 'package:student_assistance_app/services/database_service.dart';
import 'package:student_assistance_app/widgets/subject_selection_bottom_sheet.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import localization

class QuickActions extends StatelessWidget {
  final VoidCallback onNewNote;
  final VoidCallback onTimetable;
  final VoidCallback onRecord;
  final Function(String) onTakePhotoForSubject;
  final List<Map<String, dynamic>> timetable;
  final DatabaseService databaseService;

  const QuickActions({
    super.key,
    required this.onNewNote,
    required this.onTimetable,
    required this.onRecord,
    required this.onTakePhotoForSubject,
    required this.timetable,
    required this.databaseService,
  });

  // This method remains unchanged functionally
  void _showSubjectSelectionForPhoto(BuildContext context) {
    SubjectSelectionBottomSheet.show(
      context: context,
      timetable: timetable,
      databaseService: databaseService,
      isPhoto: true,
      onSubjectSelected: onTakePhotoForSubject,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the localization instance
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          l10n.quickActions, // UPDATED: Use localized string
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: Theme.of(context).cardTheme.color,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // UPDATED: Use localized strings for labels
                    _buildActionButton(
                        context, Icons.note_add, l10n.newNote, onNewNote),
                    _buildActionButton(
                        context, Icons.mic, l10n.record, onRecord),
                    _buildActionButton(
                        context,
                        Icons.camera_alt,
                        l10n.takePhoto,
                        () => _showSubjectSelectionForPhoto(context)),
                    _buildActionButton(
                        context, Icons.schedule, l10n.timetable, onTimetable),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // This widget remains unchanged as it receives the label as a parameter
  Widget _buildActionButton(BuildContext context, IconData icon, String label,
      VoidCallback onPressed) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: colorScheme.primary),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.primary.withOpacity(0.2),
            padding: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
