// lib/maintenance_checklist_page.dart

import 'package:flutter/material.dart';

// A simple class to hold our task data
class Task {
  String title;
  bool isDone;

  Task({required this.title, this.isDone = false});
}

class MaintenanceChecklistPage extends StatefulWidget {
  const MaintenanceChecklistPage({super.key});

  @override
  State<MaintenanceChecklistPage> createState() =>
      _MaintenanceChecklistPageState();
}

class _MaintenanceChecklistPageState extends State<MaintenanceChecklistPage> {
  // Controller for the text input field
  final TextEditingController _taskController = TextEditingController();

  // The list of tasks, pre-filled with the defaults from your image
  final List<Task> _tasks = [
    Task(title: 'Check cable insulation'),
    Task(title: 'Verify signal lamp'),
    Task(title: 'Check joint pit marker'),
    Task(title: 'Record megger reading'),
  ];

  // This function adds a new task to the list
  void _addTask() {
    if (_taskController.text.isNotEmpty) {
      setState(() {
        _tasks.add(Task(title: _taskController.text));
        _taskController.clear(); // Clear the text field after adding
      });
    }
  }

  @override
  void dispose() {
    _taskController
        .dispose(); // Clean up the controller when the widget is removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Tasks'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          // CheckboxListTile is a perfect widget for this use case
          return CheckboxListTile(
            title: Text(task.title),
            value: task.isDone,
            onChanged: (bool? newValue) {
              setState(() {
                task.isDone = newValue ?? false;
              });
            },
            controlAffinity:
                ListTileControlAffinity.leading, // Puts checkbox first
          );
        },
      ),
      // This bottom bar holds the input field and the "Add" button
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(
            context,
          ).viewInsets.bottom, // Moves bar up with keyboard
          left: 8.0,
          right: 8.0,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _taskController,
                decoration: const InputDecoration(
                  hintText: 'Enter new task...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, size: 35),
              onPressed: _addTask,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
