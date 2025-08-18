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
  List<LatLng> _geoPoints = [];
  LatLng? _userLocation;
  LatLng? _selectedPole;
  Stream<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
    _startLocationStream();
  }

  Future<void> _loadGeoJson() async {
    final data = await rootBundle.loadString('assets/lucknow_network.geojson');
    final jsonResult = json.decode(data);

    List<LatLng> points = [];

    for (var feature in jsonResult['features']) {
      final coords = feature['geometry']['coordinates'];
      if (coords is List && coords.length == 2) {
        points.add(LatLng(coords[1], coords[0]));
      }
    }

    setState(() {
      _geoPoints = points;
    });

    // Auto zoom to cluster
    if (points.isNotEmpty) {
      final bounds = LatLngBounds();
      for (var p in points) {
        bounds.extend(p);
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
        distanceFilter: 5, // update every 5 meters
      ),
    );

    _positionStream!.listen((pos) {
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
      });
    });
  }

  void _centerOnUser() async {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map with Live Navigation")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(26.8467, 80.9462), // Lucknow center
          initialZoom: 12,
          onTap: (tapPosition, point) {
            setState(() {
              _selectedPole = point; // Select pole
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate:
                "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
          ),

          // Yellow GeoJSON poles
          MarkerLayer(
            markers: _geoPoints
                .map((p) => Marker(
                      point: p,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on,
                          color: Colors.yellow, size: 30),
                    ))
                .toList(),
          ),

          // Blue GPS dot
          CurrentLocationLayer(),

          // Live red navigation line
          if (_userLocation != null && _selectedPole != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [_userLocation!, _selectedPole!],
                  color: Colors.red,
                  strokeWidth: 4,
                )
              ],
            ),
        ],
      ),

      // Floating GPS button
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnUser,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}                        
