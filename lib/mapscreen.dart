import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'map_view_page.dart'; // Import the MapViewPage

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  LatLng? _currentPosition;
  LatLng? _nearestPole;
  double? _nearestDistance;
  double? _cableHeight;

  // Toggle this for testing
  bool useMockLocation = true;
  LatLng mockLocation = const LatLng(26.8467, 80.9462); // Lucknow

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  // A new function to make initialization more reliable
  Future<void> _initializeMap() async {
    await _loadCableRoutes();
    await _updateLocation();

    if (!useMockLocation) {
      Timer.periodic(const Duration(seconds: 5), (_) => _updateLocation());
    }
  }

  Future<void> _loadCableRoutes() async {
    try {
      String data = await rootBundle.loadString(
        'assets/lucknow_cables.geojson',
      );
      final jsonResult = json.decode(data);

      Set<Polyline> tempPolylines = {};
      int poleCounter = 0;
      for (var feature in jsonResult['features']) {
        var coords = feature['geometry']['coordinates'];
        List<LatLng> points = coords
            .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();

        // Use a unique key for each polyline
        tempPolylines.add(
          Polyline(
            polylineId: PolylineId('pole_${poleCounter++}'),
            points: points,
            color: Colors.redAccent,
            width: 4,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _polylines = tempPolylines;
        });
      }
    } catch (e) {
      print("Error loading GeoJSON: $e");
      // Optionally show an error to the user
    }
  }

  Future<void> _updateLocation() async {
    LatLng position;
    try {
      if (useMockLocation) {
        position = mockLocation;
      } else {
        // You should add location permission handling here for a real app
        Position p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        position = LatLng(p.latitude, p.longitude);
      }

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _findNearestPole();
      }
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  void _findNearestPole() {
    if (_currentPosition == null || _polylines.isEmpty) return;

    double minDist = double.infinity;
    LatLng? nearest;
    double? height;

    for (var poly in _polylines) {
      for (var point in poly.points) {
        double dist = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          point.latitude,
          point.longitude,
        );
        if (dist < minDist) {
          minDist = dist;
          nearest = point;
          // In a real app, you would fetch height from GeoJSON properties
          height = 5.5; // Example: hardcoded height
        }
      }
    }

    if (mounted) {
      setState(() {
        _nearestPole = nearest;
        _nearestDistance = minDist;
        _cableHeight = height;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Railway Cable Map (Local)"),
        backgroundColor: const Color(0xFF2C3E50),
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 14,
                  ),
                  polylines: _polylines,
                  markers: {
                    Marker(
                      markerId: const MarkerId("user"),
                      position: _currentPosition!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                    ),
                  },
                ),
                Positioned(
                  bottom: 20,
                  left: 10,
                  right: 10,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Nearest OHE Pole: ${_nearestDistance?.toStringAsFixed(1) ?? '--'} m away",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Cable Height: ${_cableHeight ?? '--'} m",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => const MapViewPage()));
        },
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.layers),
      ),
    );
  }
}
