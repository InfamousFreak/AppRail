
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class LocationTrackerPage extends StatefulWidget {
  const LocationTrackerPage({Key? key}) : super(key: key);

  @override
  State<LocationTrackerPage> createState() => LocationTrackerPageState();
}

class LocationTrackerPageState extends State<LocationTrackerPage> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _masts = [];
  String? _selectedMast;
  LatLng? _selectedLatLng;
  LatLng? _currentLatLng;

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
    _getCurrentLocation();
  }

  Future<void> _loadGeoJson() async {
    final data =
        await rootBundle.loadString('assets/geojson/lucknow_network.geojson');
    final jsonResult = json.decode(data);

    List<Map<String, dynamic>> mastList = [];
    for (var feature in jsonResult['features']) {
      final props = feature['properties'];
      final coords = feature['geometry']['coordinates'];
      mastList.add({
        "mast": props['mast_no'] ?? "Unknown",
        "latlng": LatLng(coords[1], coords[0]),
      });
    }

    setState(() {
      _masts = mastList;
    });
  }

  Future<void> _getCurrentLocation() async {
    Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLatLng = LatLng(pos.latitude, pos.longitude);
    });
  }

  void _zoomToMast(Map<String, dynamic> mast) {
    final target = mast["latlng"] as LatLng;
    setState(() {
      _selectedMast = mast["mast"];
      _selectedLatLng = target;
    });
    _mapController.move(target, 16.0);
  }

  double? _calculateDistance(LatLng mast) {
    if (_currentLatLng == null) return null;
    final dist = Geolocator.distanceBetween(
      _currentLatLng!.latitude,
      _currentLatLng!.longitude,
      mast.latitude,
      mast.longitude,
    );
    return dist / 1000; // km
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OHE Mast Locator"),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TypeAheadField<Map<String, dynamic>>(
              textFieldConfiguration: const TextFieldConfiguration(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Search Mast No (e.g. 762/25)",
                ),
              ),
              suggestionsCallback: (pattern) {
                return _masts
                    .where((mast) =>
                        mast["mast"].toString().contains(pattern.toUpperCase()))
                    .toList();
              },
              itemBuilder: (context, mast) {
                return ListTile(
                  title: Text(mast["mast"]),
                );
              },
              onSuggestionSelected: (mast) {
                _zoomToMast(mast);
              },
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(26.8467, 80.9462), // Lucknow
                initialZoom: 12.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    if (_selectedLatLng != null)
                      Marker(
                        point: _selectedLatLng!,
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 40),
                      ),
                    if (_currentLatLng != null)
                      Marker(
                        point: _currentLatLng!,
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.my_location,
                            color: Colors.blue, size: 30),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_selectedLatLng != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Selected Mast: $_selectedMast\n"
                "Distance: ${_calculateDistance(_selectedLatLng!).toStringAsFixed(2)} km",
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

