// lib/role_selection_page.dart

import 'package:flutter/material.dart';
import 'actions_page.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  void _navigateToActionsPage(BuildContext context, String role) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => ActionsPage(selectedRole: role)),
    );
  }

  // This function shows the confirmation dialog
  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to exit the app?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Dismiss the dialog
            child: const Text('No'),
          ),
          TextButton(
            // This will pop the route and exit the app
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    ).then((exit) {
      if (exit == true) {
        // If 'Yes' was pressed, pop the current page to exit
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // We wrap the entire page in PopScope now
    return PopScope(
      // 1. We set canPop to false to prevent the back gesture.
      canPop: false,
      // 2. onPopInvoked is called when a pop is attempted.
      onPopInvoked: (bool didPop) {
        // didPop will be false because we set canPop to false.
        if (!didPop) {
          // So we show our dialog here.
          _showExitDialog(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Role'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () =>
                      _navigateToActionsPage(context, 'Field Staff'),
                  child: const Text('Field Staff'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () =>
                      _navigateToActionsPage(context, 'Supervisor'),
                  child: const Text('Supervisor'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
