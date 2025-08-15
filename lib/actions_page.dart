// lib/actions_page.dart

import 'package:flutter/material.dart';
import 'homepage.dart'; // Imports your original counter app HomePage
import 'maintenance_checklist_page.dart';
import 'map_view_page.dart';

class ActionsPage extends StatelessWidget {
  final String selectedRole;

  const ActionsPage({super.key, required this.selectedRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Message
            Text(
              'Welcome, $selectedRole!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // View Map Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MapViewPage()),
                );
              },
              child: const Text('View Map'),
            ),
            const SizedBox(height: 20),

            // Maintenance Checklist Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MaintenanceChecklistPage(),
                  ),
                );
              },
              child: const Text('Maintenance Checklist'),
            ),
            const SizedBox(height: 20),

            // Inspection History Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const MyHomePage(title: 'Inspection History'),
                  ),
                );
              },
              child: const Text('Inspection History'),
            ),
          ],
        ),
      ),
    );
  }
}
