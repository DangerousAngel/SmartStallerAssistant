import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:student_assistance_app/services/database_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// 1. IMPORT THE NOTIFICATION SERVICE
import 'package:student_assistance_app/services/notification_service.dart';
import 'package:student_assistance_app/widgets/gradient_app_bar.dart';

class TimetableScreen extends StatefulWidget {
  final DatabaseService databaseService;
  final bool hideFab;

  const TimetableScreen({
    super.key,
    required this.databaseService,
    this.hideFab = false,
  });

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<Map<String, dynamic>> _timetable = [];
  bool _isLoading = true;
  Map<String, String> _dayTranslations = {};

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _dayTranslations = {
      'Saturday': l10n.saturday,
      'Sunday': l10n.sunday,
      'Monday': l10n.monday,
      'Tuesday': l10n.tuesday,
      'Wednesday': l10n.wednesday,
      'Thursday': l10n.thursday,
      'Friday': l10n.friday,
    };
  }

  Future<void> _loadTimetable() async {
    final timetable = await widget.databaseService.getTimetable();
    if (mounted) {
      setState(() {
        _timetable = timetable;
        _isLoading = false;
      });
    }
  }

  // 2. HELPER TO CHECK IF NOTIFICATIONS ARE ON
  Future<bool> _areNotificationsEnabled() async {
    final val = await widget.databaseService.getSetting('notifications');
    return val == 'true';
  }

  void _addTimetableEntry() async {
    final l10n = AppLocalizations.of(context)!;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          TimetableDialog(initialTime: pickedTime, l10n: l10n),
    );

    if (result != null) {
      await widget.databaseService.insertTimetable(result);

      // 3. SCHEDULE NOTIFICATION IF ENABLED
      if (await _areNotificationsEnabled()) {
        await NotificationService.scheduleLectureNotification(result, l10n);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.alarmSetFor(result['subject']))),
        );
      }

      _loadTimetable();
    }
  }

  void _editTimetableEntry(Map<String, dynamic> entry) async {
    final l10n = AppLocalizations.of(context)!;
    final timeParts = entry['time'].split(' ');
    final time = timeParts[0].split(':');
    final period = timeParts[1];

    int hour = int.parse(time[0]);
    final minute = int.parse(time[1]);

    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    final initialTime = TimeOfDay(hour: hour, minute: minute);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TimetableDialog(
        initialTime: initialTime,
        initialData: entry,
        l10n: l10n,
      ),
    );

    if (result != null) {
      // 4. HANDLE NOTIFICATION UPDATE
      if (await _areNotificationsEnabled()) {
        // Cancel the OLD alarm (using the old entry data)
        await NotificationService.cancelLectureNotification(entry);
        // Schedule the NEW alarm
        await NotificationService.scheduleLectureNotification(result, l10n);
      }

      await widget.databaseService.updateTimetable(entry['id'], result);
      _loadTimetable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: GradientAppBar(
        title: Text(l10n.timetable),
        leading: const Icon(Icons.calendar_today),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTimetable(),
      floatingActionButton: widget.hideFab
          ? null
          : FloatingActionButton(
              onPressed: _addTimetableEntry,
              child: const Icon(Icons.add, color: Colors.black),
              backgroundColor: const Color.fromRGBO(210, 181, 138, 1)),
    );
  }

  Widget _buildTimetable() {
    // ... [This part of your code remains exactly the same] ...
    // Just copy your existing _buildTimetable code here
    final l10n = AppLocalizations.of(context)!;
    final days = [
      'Saturday',
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday'
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final dayEntries =
            _timetable.where((entry) => entry['day'] == day).toList();

        dayEntries.sort((a, b) {
          DateTime timeA = DateFormat('h:mm a').parse(a['time']);
          DateTime timeB = DateFormat('h:mm a').parse(b['time']);
          return timeA.compareTo(timeB);
        });

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    )),
                child: Text(
                  _dayTranslations[day] ?? day,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
              if (dayEntries.isEmpty)
                ListTile(
                    leading: Icon(Icons.info_outline,
                        color: Theme.of(context).hintColor),
                    title: Text(l10n.noClassesScheduled,
                        style: TextStyle(color: Theme.of(context).hintColor)))
              else
                ...dayEntries
                    .map((entry) => _buildTimetableEntry(entry))
                    .toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimetableEntry(Map<String, dynamic> entry) {
    return ListTile(
      leading:
          Icon(Icons.schedule, color: Theme.of(context).colorScheme.secondary),
      title: Text(entry['subject']),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${entry['time']} • ${entry['room'] ?? 'No room'}'),
          if (entry['professor'] != null && entry['professor'].isNotEmpty)
            Text('Dr. ${entry['professor']}',
                style: const TextStyle(fontSize: 12)),
        ],
      ),
      onTap: () => _editTimetableEntry(entry),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: () => _editTimetableEntry(entry),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.grey),
            onPressed: () async {
              // 5. CANCEL NOTIFICATION ON DELETE
              if (await _areNotificationsEnabled()) {
                await NotificationService.cancelLectureNotification(entry);
              }
              await widget.databaseService.deleteTimetable(entry['id']);
              _loadTimetable();
            },
          ),
        ],
      ),
    );
  }
}

// ... [TimetableDialog class remains exactly the same] ...

class TimetableDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final Map<String, dynamic>? initialData;
  final AppLocalizations l10n; // Passed in for localization

  const TimetableDialog(
      {super.key,
      required this.initialTime,
      this.initialData,
      required this.l10n});

  @override
  State<TimetableDialog> createState() => _TimetableDialogState();
}

class _TimetableDialogState extends State<TimetableDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _roomController = TextEditingController();
  final _professorController = TextEditingController();
  String _selectedDay = 'Saturday';
  TimeOfDay _selectedTime = TimeOfDay.now();
  Map<String, String> _dayTranslations = {};

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;

    // Initialize translations from the passed l10n instance
    _dayTranslations = {
      'Saturday': widget.l10n.saturday,
      'Sunday': widget.l10n.sunday,
      'Monday': widget.l10n.monday,
      'Tuesday': widget.l10n.tuesday,
      'Wednesday': widget.l10n.wednesday,
      'Thursday': widget.l10n.thursday,
      'Friday': widget.l10n.friday,
    };

    if (widget.initialData != null) {
      _selectedDay = widget.initialData!['day'] ?? 'Saturday';
      _subjectController.text = widget.initialData!['subject'] ?? '';
      _roomController.text = widget.initialData!['room'] ?? '';
      _professorController.text = widget.initialData!['professor'] ?? '';
    }
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final format = DateFormat.jm(); // Uses AM/PM
    return format.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(widget.initialData != null
          ? l10n.editTimetableEntry
          : l10n.addTimetableEntry),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedDay,
                items: _dayTranslations.keys
                    .map((day) => DropdownMenuItem(
                        value: day,
                        child:
                            Text(_dayTranslations[day]!) // Show translated day
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedDay = value!),
                decoration: InputDecoration(
                  labelText: l10n.day,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text(l10n.time),
                subtitle: Text(_formatTime(_selectedTime)),
                onTap: () async {
                  final TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (pickedTime != null) {
                    setState(() => _selectedTime = pickedTime);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                textDirection: l10n.localeName == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.subject,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.pleaseEnterSubject;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roomController,
                textDirection: l10n.localeName == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.hallOptional,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _professorController,
                textDirection: l10n.localeName == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.doctorOptional,
                  border: const OutlineInputBorder(),
                ),
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
              Navigator.pop(context, {
                'day': _selectedDay,
                'time': _formatTime(_selectedTime),
                'subject': _subjectController.text,
                'room': _roomController.text,
                'professor': _professorController.text,
              });
            }
          },
          child: Text(widget.initialData != null ? l10n.save : l10n.add),
        ),
      ],
    );
  }
}
