// lib/map_view_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'location_tracker_page.dart';

class MapViewPage extends StatefulWidget {
  const MapViewPage({super.key});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  // Controllers for the text fields
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _zoomController;

  // Controller for the map itself
  late final MapController _mapController;

  // Initial map values
  static const _initialCenter = LatLng(
    28.6139,
    77.2090,
  ); // Default to Delhi, India
  static const _initialZoom = 10.0;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with default values
    _latController = TextEditingController(
      text: _initialCenter.latitude.toString(),
    );
    _lngController = TextEditingController(
      text: _initialCenter.longitude.toString(),
    );
    _zoomController = TextEditingController(text: _initialZoom.toString());
    _mapController = MapController();
  }

  @override
  void dispose() {
    // Clean up controllers
    _latController.dispose();
    _lngController.dispose();
    _zoomController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // This function is called when the "Apply" button is pressed
  void _applyChanges() {
    // Get values from text fields and parse them
    final double? lat = double.tryParse(_latController.text);
    final double? lng = double.tryParse(_lngController.text);
    final double? zoom = double.tryParse(_zoomController.text);

    // Check if all values are valid
    if (lat != null && lng != null && zoom != null) {
      // Use the map controller to move the map to the new location and zoom
      _mapController.move(LatLng(lat, lng), zoom);
    } else {
      // Show an error message if input is invalid
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid input. Please enter valid numbers.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rail Route Aid - Map View'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Input section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                const Text(
                  'Token-free map using OpenStreetMap tiles. Adjust location using numbers below.',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Latitude Field
                    Expanded(
                      child: TextField(
                        controller: _latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Longitude Field
                    Expanded(
                      child: TextField(
                        controller: _lngController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Zoom Field
                    Expanded(
                      child: TextField(
                        controller: _zoomController,
                        decoration: const InputDecoration(
                          labelText: 'Zoom',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Apply Button
                ElevatedButton(
                  onPressed: _applyChanges,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
          // Map section
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _initialCenter,
                initialZoom: _initialZoom,
              ),
              children: [
                // The actual map tiles from OpenStreetMap
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.example.app', // Replace with your app's package name
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to the location tracker page
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const LocationTrackerPage(),
            ),
          );
        },
        label: const Text('Track Location'),
        icon: const Icon(Icons.gps_fixed),
      ),
    );
  }
}
