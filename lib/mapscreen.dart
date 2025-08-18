import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:geodesy/geodesy.dart'; // For distance calculation

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  LatLng? _currentLocation;
  String _nearestInfo = "Locating...";

  final Geodesy geodesy = Geodesy();

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
    _getCurrentLocation();
  }

  // Load merged GeoJSON
  Future<void> _loadGeoJson() async {
    final data = await rootBundle.loadString('assets/lucknow_network.geojson');
    final jsonResult = json.decode(data);

    List<Polyline> tempPolylines = [];
    List<Marker> tempMarkers = [];

    for (var feature in jsonResult['features']) {
      String type = feature['geometry']['type'];

      if (type == 'LineString') {
        var coords = feature['geometry']['coordinates'];
        List<LatLng> points =
            coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();

        tempPolylines.add(Polyline(
          points: points,
          strokeWidth: 3,
          color: Colors.yellow,
        ));
      }

      if (type == 'Point') {
        var coords = feature['geometry']['coordinates'];
        LatLng point = LatLng(coords[1], coords[0]);

        tempMarkers.add(Marker(
          width: 20.0,
          height: 20.0,
          point: point,
          builder: (ctx) => const Icon(
            Icons.circle,
            color: Colors.yellow,
            size: 10,
          ),
        ));
      }
    }

    setState(() {
      _polylines = tempPolylines;
      _markers = tempMarkers;
    });
  }

  // Get current GPS + nearest pole distance
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    LatLng userLoc = LatLng(position.latitude, position.longitude);

    // Nearest pole calculation
    double minDist = double.infinity;
    LatLng? nearestPole;

    for (var marker in _markers) {
      double d = geodesy.distanceBetweenTwoGeoPoints(
          userLoc, LatLng(marker.point.latitude, marker.point.longitude));
      if (d < minDist) {
        minDist = d;
        nearestPole = marker.point;
      }
    }

    setState(() {
      _currentLocation = userLoc;
      if (nearestPole != null) {
        _nearestInfo = "Nearest Pole: ${(minDist).toStringAsFixed(1)} meters";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lucknow Railway Demo"),
        backgroundColor: Colors.red,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: LatLng(26.8467, 80.9462), // Lucknow
              zoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
              if (_currentLocation != null)
                MarkerLayer(markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: _currentLocation!,
                    builder: (ctx) => const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                ]),
            ],
          ),

          // ✅ Info bar bottom
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _nearestInfo,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.location_searching),
      ),
    );
  }
}
