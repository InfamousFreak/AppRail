import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart' show rootBundle;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentLocation;
  List<LatLng> _ohePoles = [];
  LatLng? _nearestPole;
  double? _distanceToNearest;
  List<LatLng> _navLine = [];

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
    _determinePosition();
  }

  /// ✅ Load merged GeoJSON from assets
  Future<void> _loadGeoJson() async {
    final data = await rootBundle.loadString('assets/lucknow_network.geojson');
    final geojson = json.decode(data);

    List<LatLng> poles = [];
    for (var feature in geojson['features']) {
      if (feature['geometry']['type'] == 'Point') {
        var coords = feature['geometry']['coordinates'];
        poles.add(LatLng(coords[1], coords[0]));
      }
    }

    setState(() {
      _ohePoles = poles;
    });
  }

  /// ✅ Request GPS permission & track location
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
      ),
    ).listen((Position pos) {
      LatLng current = LatLng(pos.latitude, pos.longitude);
      _updateNearestPole(current);
    });
  }

  /// ✅ Find nearest OHE pole & distance
  void _updateNearestPole(LatLng current) {
    if (_ohePoles.isEmpty) return;

    final distance = Distance();
    LatLng nearest = _ohePoles.first;
    double minDist = distance(current, nearest);

    for (var pole in _ohePoles) {
      double d = distance(current, pole);
      if (d < minDist) {
        nearest = pole;
        minDist = d;
      }
    }

    setState(() {
      _currentLocation = current;
      _nearestPole = nearest;
      _distanceToNearest = minDist;
      _navLine = [current, nearest];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lucknow Railway OHE Map"),
        backgroundColor: Colors.red,
      ),
      body: _ohePoles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(26.8467, 80.9462), // Lucknow
                initialZoom: 14,
              ),
              children: [
                /// ✅ Map tiles from OpenStreetMap
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.railway_app',
                ),

                /// ✅ OHE Poles Markers
                MarkerLayer(
                  markers: _ohePoles
                      .map(
                        (pole) => Marker(
                          point: pole,
                          width: 10,
                          height: 10,
                          child: const Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.yellow,
                          ),
                        ),
                      )
                      .toList(),
                ),

                /// ✅ User Location Marker
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 28,
                        ),
                      ),
                    ],
                  ),

                /// ✅ Navigation line (User → Nearest pole)
                if (_navLine.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _navLine,
                        strokeWidth: 4,
                        color: Colors.red,
                      ),
                    ],
                  ),
              ],
            ),
      bottomNavigationBar: _nearestPole != null
          ? Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Text(
                "Nearest Pole: ${_nearestPole!.latitude.toStringAsFixed(5)}, "
                "${_nearestPole!.longitude.toStringAsFixed(5)}\n"
                "Distance: ${_distanceToNearest!.toStringAsFixed(1)} meters",
                style: const TextStyle(fontSize: 16),
              ),
            )
          : null,
    );
  }
}
  
      
