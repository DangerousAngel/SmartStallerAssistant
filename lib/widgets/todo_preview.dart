import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_assistance_app/services/database_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TodoPreview extends StatefulWidget {
  final DatabaseService databaseService;
  final VoidCallback onTap;
  const TodoPreview(
      {super.key, required this.databaseService, required this.onTap});

  @override
  State<TodoPreview> createState() => _TodoPreviewState();
}

class _TodoPreviewState extends State<TodoPreview> {
  Map<String, dynamic>? _nextTodo;
  bool _loading = true, _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final todos = await widget.databaseService.getTodos(filter: 'pending');

      // Simply take the first/latest task - no sorting by priority
      setState(() {
        _nextTodo = todos.isNotEmpty ? todos.first : null;
        _loading = false;
        _error = false;
      });
    } catch (e) {
      print("Error loading todos: $e");
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Color _pColor(int p) =>
      [Colors.grey, Colors.green, Colors.orange, Colors.red][p.clamp(0, 3)];
  String _pText(int p, l10n) =>
      [l10n.low, l10n.low, l10n.medium, l10n.high][p.clamp(0, 3)];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else if (_error) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
            const SizedBox(height: 8),
            Text(l10n.failedToLoadTasks,
                style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: Text(l10n.tryAgain))
          ],
        ),
      );
    } else if (_nextTodo == null) {
      body = Center(
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.surfaceVariant
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline,
                  color: onSurface.withOpacity(0.5), size: 32),
              const SizedBox(height: 8),
              Text(l10n.noTasks,
                  style: TextStyle(color: onSurface.withOpacity(0.7))),
              const SizedBox(height: 4),
              Text(l10n.tapToAddTask,
                  style:
                      TextStyle(color: theme.colorScheme.primary, fontSize: 12))
            ]),
          ),
        ),
      );
    } else {
      final t = _nextTodo!;
      final p = t['priority'] ?? 1;
      final d = t['dueDate'];
      final due = d != null ? DateTime.parse(d) : null;
      final overdue = due != null && due.isBefore(DateTime.now());
      final pc = _pColor(p);

      body = InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceVariant
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(children: [
            Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: pc,
                  borderRadius: BorderRadius.circular(2),
                )),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['title']?.toString() ?? '-',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (t['description'] != null &&
                        t['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        t['description'].toString(),
                        style: TextStyle(
                            color: onSurface.withOpacity(0.7), fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: pc.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: pc.withOpacity(0.3))),
                        child: Text(_pText(p, l10n),
                            style: TextStyle(
                                color: pc,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (due != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today,
                            size: 14,
                            color: overdue
                                ? Colors.red
                                : onSurface.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(DateFormat('MMM dd').format(due),
                            style: TextStyle(
                                fontSize: 12,
                                color: overdue
                                    ? Colors.red
                                    : onSurface.withOpacity(0.6),
                                fontWeight: overdue
                                    ? FontWeight.bold
                                    : FontWeight.normal))
                      ]
                    ])
                  ]),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: theme.colorScheme.primary)
          ]),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.checklist, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(l10n.nextTask,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 18)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.refresh,
                  size: 20, color: theme.colorScheme.primary),
              onPressed: _load,
              tooltip: l10n.refresh,
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward,
                  size: 20, color: theme.colorScheme.primary),
              onPressed: widget.onTap,
              tooltip: l10n.viewAllTasks,
            ),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          SizedBox(height: 120, child: body),
        ]),
      ),
    );
  }
}
