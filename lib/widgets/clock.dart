import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TimeWidget extends StatefulWidget {
  const TimeWidget({super.key});

  @override
  State<TimeWidget> createState() => _TimeWidgetState();
}

class _TimeWidgetState extends State<TimeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  DateTime _currentTime = DateTime.now();
  Map<String, String> _dayTranslations = {};

  static const _dayColors = {
    'Saturday': Colors.teal, 'Sunday': Colors.pink, 'Monday': Colors.blue,
    'Tuesday': Colors.green, 'Wednesday': Colors.orange, 'Thursday': Colors.purple,
    'Friday': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    
    // Animation controller for smooth time updates
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    
    // Update time every second
    _controller.addListener(() {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _dayTranslations = {
      'Saturday': l10n.saturday, 'Sunday': l10n.sunday, 'Monday': l10n.monday,
      'Tuesday': l10n.tuesday, 'Wednesday': l10n.wednesday, 'Thursday': l10n.thursday,
      'Friday': l10n.friday,
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getCurrentDay(DateTime date) {
    const dayMap = {
      DateTime.saturday: 'Saturday', DateTime.sunday: 'Sunday', DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday', DateTime.wednesday: 'Wednesday', DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
    };
    return dayMap[date.weekday] ?? 'Monday';
  }

  Color _getDayColor(String day) => _dayColors[day] ?? Colors.grey;
  String _getTranslatedDay(String englishDay) => _dayTranslations[englishDay] ?? englishDay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final day = _getCurrentDay(_currentTime);
    final dayColor = _getDayColor(day);
    final translatedDay = _getTranslatedDay(day);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      color: isDark
          ? Theme.of(context).colorScheme.surface
          : Colors.white.withAlpha(255).withOpacity(1),
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Center(
          child: FittedBox(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Time display with smooth animation
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return RichText(
                      text: TextSpan(
                        children: [
                          // Hours and minutes
                          TextSpan(
                            text: DateFormat('h:mm').format(_currentTime),
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          // Seconds with smaller font
                          TextSpan(
                            text: ':${DateFormat('ss').format(_currentTime)}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                            ),
                          ),
                          // AM/PM indicator
                          TextSpan(
                            text: ' ${DateFormat('a').format(_currentTime)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 26),
                // Day of the week display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: dayColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dayColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    translatedDay,
                    style: TextStyle(
                      color: dayColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}