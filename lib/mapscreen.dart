import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  List<LatLng> _geoJsonLine = [];
  LatLng? _userLocation;
  final List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _loadGeoJson();
    _getUserLocation();
  }

  /// Load GeoJSON railway data from assets
  Future<void> _loadGeoJson() async {
    final String data = await rootBundle.loadString("assets/lucknow_network.geojson");
    final jsonResult = json.decode(data);

    List<LatLng> points = [];

    if (jsonResult["features"] != null) {
      for (var feature in jsonResult["features"]) {
        if (feature["geometry"]["type"] == "LineString") {
          List coords = feature["geometry"]["coordinates"];
          for (var coord in coords) {
            points.add(LatLng(coord[1], coord[0])); // [lon, lat] → (lat, lon)
          }
        }
      }
    }

    setState(() {
      _geoJsonLine = points;
    });
  }

  /// Get current location & update marker
  Future<void> _getUserLocation() async {
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
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _markers.clear();
        _markers.add(
          Marker(
            point: _userLocation!,
            width: 40,
            height: 40,
            child: const Icon(Icons.location_on, color: Colors.red, size: 35),
          ),
        );
      });

      // move map with user
      _mapController.move(_userLocation!, _mapController.camera.zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lucknow Railway Map")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(26.8467, 80.9462), // Lucknow center
          initialZoom: 12,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
          ),
          if (_geoJsonLine.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _geoJsonLine,
                  strokeWidth: 4.0,
                  color: Colors.blue,
                ),
              ],
            ),
          MarkerLayer(markers: _markers),
        ],
      ),
    );
  }
}