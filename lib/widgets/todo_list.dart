import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:student_assistance_app/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TodoList extends StatefulWidget {
  final DatabaseService databaseService;

  const TodoList({super.key, required this.databaseService});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  List<Map<String, dynamic>> _todos = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _currentFilter = 'all'; // 'all', 'pending', 'completed'

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    try {
      final todos = await widget.databaseService.getTodos(
        filter: _currentFilter == 'all' ? null : _currentFilter,
      );

      if (mounted) {
        setState(() {
          _todos = todos;
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

  void _setFilter(String filter) {
    setState(() {
      _currentFilter = filter;
      _isLoading = true;
    });
    _loadTodos();
  }

  Future<void> _addTodo() async {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    DateTime? selectedDate;
    int selectedPriority = 1;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.addNewTask),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textDirection: l10n.localeName == 'ar'
                      ? ui.TextDirection.rtl
                      : ui.TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.taskTitle,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  textDirection: l10n.localeName == 'ar'
                      ? ui.TextDirection.rtl
                      : ui.TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('${l10n.priority}: '),
                    const Spacer(),
                    DropdownButton<int>(
                      value: selectedPriority,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedPriority = value!;
                        });
                      },
                      items: [
                        DropdownMenuItem(
                          value: 1,
                          child: Text(l10n.low),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(l10n.medium),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(l10n.high),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('${l10n.dueDate}: '),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Text(
                        selectedDate != null
                            ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                            : l10n.selectDate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isNotEmpty) {
                  await widget.databaseService.insertTodo({
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'priority': selectedPriority,
                    'dueDate': selectedDate?.toIso8601String(),
                    'isCompleted': 0,
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                    _loadTodos();
                  }
                }
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTodoCompletion(int id, bool isCompleted) async {
    await widget.databaseService.toggleTodoCompletion(id, !isCompleted);
    _loadTodos();
  }

  Future<void> _deleteTodo(int id) async {
    await widget.databaseService.deleteTodo(id);
    _loadTodos();
  }

  Future<void> _editTodo(Map<String, dynamic> todo) async {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController(text: todo['title']);
    final descriptionController =
        TextEditingController(text: todo['description']);
    DateTime? selectedDate =
        todo['dueDate'] != null ? DateTime.parse(todo['dueDate']) : null;
    int selectedPriority = todo['priority'] ?? 1;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.editTask),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textDirection: l10n.localeName == 'ar'
                      ? ui.TextDirection.rtl
                      : ui.TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.taskTitle,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  textDirection: l10n.localeName == 'ar'
                      ? ui.TextDirection.rtl
                      : ui.TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('${l10n.priority}: '),
                    const Spacer(),
                    DropdownButton<int>(
                      value: selectedPriority,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedPriority = value!;
                        });
                      },
                      items: [
                        DropdownMenuItem(
                          value: 1,
                          child: Text(l10n.low),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(l10n.medium),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(l10n.high),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('${l10n.dueDate}: '),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Text(
                        selectedDate != null
                            ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                            : l10n.selectDate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isNotEmpty) {
                  await widget.databaseService.updateTodo(todo['id'], {
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'priority': selectedPriority,
                    'dueDate': selectedDate?.toIso8601String(),
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                    _loadTodos();
                  }
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(int priority, AppLocalizations l10n) {
    switch (priority) {
      case 1:
        return l10n.low;
      case 2:
        return l10n.medium;
      case 3:
        return l10n.high;
      default:
        return l10n.low;
    }
  }

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
          : Colors.white.withOpacity(1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist,
                    color: Theme.of(context).colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  l10n.todoList,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.add,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  onPressed: _addTodo,
                  tooltip: l10n.addNewTask,
                ),
                IconButton(
                  icon: Icon(Icons.refresh,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  onPressed: _loadTodos,
                  tooltip: l10n.refresh,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter chips
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(l10n.all),
                      selected: _currentFilter == 'all',
                      onSelected: (selected) => _setFilter('all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(l10n.pending),
                      selected: _currentFilter == 'pending',
                      onSelected: (selected) => _setFilter('pending'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(l10n.completed),
                      selected: _currentFilter == 'completed',
                      onSelected: (selected) => _setFilter('completed'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            const SizedBox(height: 16),

            if (_isLoading)
              _buildLoadingState()
            else if (_hasError)
              _buildErrorState(context)
            else if (_todos.isEmpty)
              _buildEmptyState(context)
            else
              // ✅ Scrollable ListView
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _todos.length,
                  itemBuilder: (context, index) =>
                      _buildTodoItem(_todos[index], context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );

  Widget _buildErrorState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Icon(Icons.error_outline,
            color: Theme.of(context).colorScheme.error, size: 32),
        const SizedBox(height: 8),
        Text(l10n.failedToLoadTasks,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _loadTodos,
          child: Text(l10n.tryAgain),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        children: [
          Icon(Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              size: 32),
          const SizedBox(height: 8),
          Text(
            l10n.noTasks,
            style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(Map<String, dynamic> todo, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCompleted = todo['isCompleted'] == 1;
    final priority = todo['priority'] ?? 1;
    final dueDate =
        todo['dueDate'] != null ? DateTime.parse(todo['dueDate']) : null;
    final priorityColor = _getPriorityColor(priority);
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
                : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          IconButton(
            icon: Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted ? Colors.green : priorityColor,
            ),
            onPressed: () => _toggleTodoCompletion(todo['id'], isCompleted),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo['title'] ?? 'No title',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: onSurface,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (todo['description'] != null &&
                    todo['description'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      todo['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: onSurface.withOpacity(0.7),
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: priorityColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        _getPriorityText(priority, l10n),
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (dueDate != null)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd').format(dueDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: dueDate.isBefore(DateTime.now()) &&
                                      !isCompleted
                                  ? Colors.red
                                  : onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => _editTodo(todo),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.editNote),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => _deleteTodo(todo['id']),
                child: Row(
                  children: [
                    const Icon(Icons.delete, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(l10n.delete),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
