 import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class LocationTrackerPage extends StatefulWidget {
  const LocationTrackerPage({super.key});

  @override
  State<LocationTrackerPage> createState() => _LocationTrackerPageState();
}

class _LocationTrackerPageState extends State<LocationTrackerPage> {
  final MapController _mapController = MapController();

  LatLng? _userLocation;
  List<Marker> _mastMarkers = [];
  Map<String, LatLng> _mastMap = {}; // mastNo -> coordinates
  List<Polyline> _polylines = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
    _getUserLocation();
  }

  /// Load mast poles from GeoJSON
  Future<void> _loadGeoJson() async {
    String data =
        await rootBundle.loadString('assets/geojson/lucknow_network.geojson');
    final jsonResult = json.decode(data);

    List features = jsonResult["features"];
    List<Marker> markers = {};
    Map<String, LatLng> mastMap = {};

    for (var feature in features) {
      var coords = feature["geometry"]["coordinates"];
      String mastNo = feature["properties"]["name"] ?? "Unknown Mast";
      LatLng point = LatLng(coords[1], coords[0]);

      mastMap[mastNo] = point;

      markers.add(
        Marker(
          point: point,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 35),
        ),
      );
    }

    setState(() {
      _mastMarkers = markers.toList();
      _mastMap = mastMap;
    });
  }

  /// Get user's current location
  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
    });

    _mapController.move(_userLocation!, 15);
  }

  /// Calculate distance between user & mast
  double _calculateDistance(LatLng user, LatLng mast) {
    final Distance distance = const Distance();
    return distance.as(LengthUnit.Meter, user, mast);
  }

  /// Search Mast by number
  void _searchMast() {
    String query = _searchController.text.trim();
    if (_mastMap.containsKey(query)) {
      LatLng mastPoint = _mastMap[query]!;

      setState(() {
        _polylines = [
          Polyline(
            points: [_userLocation!, mastPoint],
            strokeWidth: 4.0,
            color: Colors.blue,
          ),
        ];
      });

      // Move camera to mast
      _mapController.move(mastPoint, 17);

      // Show distance
      if (_userLocation != null) {
        double dist = _calculateDistance(_userLocation!, mastPoint);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Distance to $query: ${dist.toStringAsFixed(1)} m")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mast not found!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lucknow OHE Pole Tracker")),
      body: Column(
        children: [
          // 🔍 Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Enter Mast No (e.g. 762/25)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchMast,
                )
              ],
            ),
          ),

          // 📍 Map
          Expanded(
            child: _userLocation == null
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _userLocation!,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(markers: [
                        if (_userLocation != null)
                          Marker(
                            point: _userLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.person_pin_circle,
                                color: Colors.blue, size: 40),
                          ),
                        ..._mastMarkers,
                      ]),
                      PolylineLayer(polylines: _polylines),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}     
