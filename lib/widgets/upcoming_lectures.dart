import 'package:flutter/material.dart';
import 'package:student_assistance_app/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class UpcomingLectures extends StatefulWidget {
  final DatabaseService databaseService;

  const UpcomingLectures({super.key, required this.databaseService});

  @override
  State<UpcomingLectures> createState() => _UpcomingLecturesState();
}

class _UpcomingLecturesState extends State<UpcomingLectures> {
  List<Map<String, dynamic>> _upcomingLectures = [];
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, String> _dayTranslations = {};

  static const _dayColors = {
    'Saturday': Colors.teal,
    'Sunday': Colors.pink,
    'Monday': Colors.blue,
    'Tuesday': Colors.green,
    'Wednesday': Colors.orange,
    'Thursday': Colors.purple,
    'Friday': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _loadUpcomingLectures();
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

  Future<void> _loadUpcomingLectures() async {
    try {
      final timetable = await widget.databaseService.getTimetable();
      final now = DateTime.now();

      final upcoming = LectureLogic.processLectures(timetable, now);

      if (mounted) {
        setState(() {
          _upcomingLectures = upcoming;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Color _getDayColor(String day) => _dayColors[day] ?? Colors.grey;
  String _getTranslatedDay(String englishDay) =>
      _dayTranslations[englishDay] ?? englishDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      color: isDark
          ? Theme.of(context).colorScheme.surface
          : Colors.white.withAlpha(255).withOpacity(1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule,
                    color: Theme.of(context).colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  l10n.upcomingLectures,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  onPressed: _loadUpcomingLectures,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
                color: Theme.of(context).dividerColor,
                height: 1,
                endIndent: 100),
            const SizedBox(height: 16),
            if (_isLoading)
              _buildLoadingState()
            else if (_hasError)
              _buildErrorState(context)
            else if (_upcomingLectures.isEmpty)
              _buildEmptyState(context)
            else
              Column(
                  children: _upcomingLectures
                      .map((lecture) => _buildLectureItem(lecture, context))
                      .toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );

  Widget _buildErrorState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error, size: 32),
          const SizedBox(height: 8),
          Text(l10n.failedToLoadLectures,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadUpcomingLectures,
            child: Text(l10n.tryAgain),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.calendar_today,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                size: 32),
            const SizedBox(height: 8),
            Text(l10n.noUpcomingLectures,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildLectureItem(Map<String, dynamic> lecture, BuildContext context) {
    final day = lecture['day']?.toString() ?? '';
    final dayColor = _getDayColor(day);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final translatedDay = _getTranslatedDay(day);

    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceVariant
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).dividerColor
                : Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, size: 16, color: onSurface),
                    const SizedBox(width: 6),
                    Text(
                      lecture['subject']?.toString() ?? 'No subject',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 16, color: onSurface.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(lecture['time']?.toString() ?? 'No time',
                        style: TextStyle(
                            fontSize: 14, color: onSurface.withOpacity(0.7))),
                    const SizedBox(width: 16),
                    if (lecture['room'] != null &&
                        lecture['room'].toString().isNotEmpty)
                      Icon(Icons.location_on,
                          size: 16, color: onSurface.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(lecture['room']?.toString() ?? '',
                        style: TextStyle(
                            fontSize: 13, color: onSurface.withOpacity(0.6))),
                  ],
                ),
                if (lecture['professor'] != null &&
                    lecture['professor'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 14, color: dayColor),
                        const SizedBox(width: 4),
                        Text('${l10n.dr} ${lecture['professor']}',
                            style: TextStyle(
                                fontSize: 13,
                                color: onSurface.withOpacity(0.6))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: dayColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dayColor.withOpacity(0.3)),
            ),
            child: Text(
              translatedDay,
              style: TextStyle(
                  color: dayColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class LectureLogic {
  static List<Map<String, dynamic>> processLectures(
    List<Map<String, dynamic>> rawLectures,
    DateTime now,
  ) {
    if (rawLectures.isEmpty) return [];

    final lectures = rawLectures
        .map((data) {
          return Lecture.fromMap(data);
        })
        .where((l) => l.isValid)
        .toList();

    if (lectures.isEmpty) return [];

    lectures.sort((a, b) => a.weeklyOffset.compareTo(b.weeklyOffset));

    final currentDayIndex = _getDayIndex(DateFormat('EEEE').format(now));
    final currentOffset =
        (currentDayIndex * 24 * 60) + (now.hour * 60) + now.minute;

    final upcoming = <Lecture>[];

    for (final lecture in lectures) {
      if (lecture.weeklyOffset > currentOffset) {
        upcoming.add(lecture);
      }
    }

    if (upcoming.length < 3) {
      for (final lecture in lectures) {
        if (upcoming.length >= 3) break;

        if (!upcoming.contains(lecture)) {
          upcoming.add(lecture);
        }
      }
    }

    return upcoming.map((l) => l.originalData).toList();
  }

  static int _getDayIndex(String day) {
    switch (day) {
      case 'Saturday':
        return 0;
      case 'Sunday':
        return 1;
      case 'Monday':
        return 2;
      case 'Tuesday':
        return 3;
      case 'Wednesday':
        return 4;
      case 'Thursday':
        return 5;
      case 'Friday':
        return 6;
      default:
        return 0;
    }
  }
}

class Lecture {
  final Map<String, dynamic> originalData;
  final int weeklyOffset;
  final bool isValid;

  Lecture._(this.originalData, this.weeklyOffset, this.isValid);

  factory Lecture.fromMap(Map<String, dynamic> data) {
    try {
      final day = data['day']?.toString();
      final time = data['time']?.toString();

      if (day == null || time == null) {
        return Lecture._(data, 0, false);
      }

      final dayIndex = LectureLogic._getDayIndex(day);
      final minutes = _parseTime(time);

      return Lecture._(
        data,
        (dayIndex * 24 * 60) + minutes,
        true,
      );
    } catch (e) {
      return Lecture._(data, 0, false);
    }
  }

  static int _parseTime(String timeStr) {
    timeStr = timeStr.toUpperCase().trim();

    int hour = 0;
    int minute = 0;
    bool isPm = timeStr.contains('PM');
    bool isAm = timeStr.contains('AM');

    final cleanTime = timeStr.replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = cleanTime.split(':');

    if (parts.length >= 2) {
      hour = int.tryParse(parts[0]) ?? 0;
      minute = int.tryParse(parts[1]) ?? 0;
    }

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    return (hour * 60) + minute;
  }
}
