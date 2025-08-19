import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _geoPoles = []; // stores pole number + LatLng
  LatLng? _userLocation;
  Map<String, dynamic>? _selectedPole;
  Stream<Position>? _positionStream;
  final TextEditingController _searchController = TextEditingController();
  double? _distanceToPole;

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
    _startLocationStream();
  }

  Future<void> _loadGeoJson() async {
    final data = await rootBundle.loadString('assets/lucknow_network.geojson');
    final jsonResult = json.decode(data);

    List<Map<String, dynamic>> poles = [];

    for (var feature in jsonResult['features']) {
      final coords = feature['geometry']['coordinates'];
      final properties = feature['properties'];
      if (coords is List && coords.length == 2) {
        poles.add({
          "number": properties['number'] ?? "Unknown",
          "latLng": LatLng(coords[1], coords[0]),
        });
      }
    }

    setState(() {
      _geoPoles = poles;
    });

    // Auto zoom to all poles initially
    if (poles.isNotEmpty) {
      final bounds = LatLngBounds();
      for (var p in poles) {
        bounds.extend(p['latLng']);
      }
      _mapController.fitBounds(bounds,
          options: const FitBoundsOptions(padding: EdgeInsets.all(30)));
    }
  }

  void _startLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    );

    _positionStream!.listen((pos) {
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _updateDistance();
      });
    });
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16);
    }
  }

  void _updateDistance() {
    if (_userLocation != null && _selectedPole != null) {
      final Distance distance = Distance();
      _distanceToPole =
          distance.as(LengthUnit.Meter, _userLocation!, _selectedPole!['latLng']);
    }
  }

  void _searchPole(String number) {
    final found = _geoPoles.firstWhere(
      (p) => p['number'].toString() == number,
      orElse: () => {},
    );

    if (found.isNotEmpty) {
      setState(() {
        _selectedPole = found;
        _updateDistance();
      });

      // Auto zoom to selected pole
      _mapController.move(found['latLng'], 18);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pole not found!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OHE Poles Map")),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(26.8467, 80.9462),
              initialZoom: 12,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPole = _geoPoles.firstWhere(
                      (p) => p['latLng'] == point,
                      orElse: () => _selectedPole);
                  _updateDistance();
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),

              // Yellow poles markers
              MarkerLayer(
                markers: _geoPoles
                    .map((p) => Marker(
                          point: p['latLng'],
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on,
                              color: Colors.yellow, size: 30),
                        ))
                    .toList(),
              ),

              // Blue GPS dot
              CurrentLocationLayer(),

              // Red navigation line
              if (_userLocation != null && _selectedPole != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_userLocation!, _selectedPole!['latLng']],
                      color: Colors.red,
                      strokeWidth: 4,
                    )
                  ],
                ),
            ],
          ),

          // Search bar at top
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Enter Pole Number",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      _searchPole(_searchController.text.trim());
                    },
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  _searchPole(value.trim());
                },
              ),
            ),
          ),

          // Distance display
          if (_distanceToPole != null)
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.white70,
                child: Text(
                  "Distance to pole: ${_distanceToPole!.toStringAsFixed(1)} m",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnUser,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
            
