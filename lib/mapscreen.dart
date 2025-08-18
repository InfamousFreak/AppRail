
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? currentLocation;
  final MapController _mapController = MapController();
  List<LatLng> cablePoints = [];
  List<Marker> poleMarkers = [];
  Map<String, dynamic> poleData = {};
  double? nearestPoleDistance;
  bool locationTried = false;
  bool followUser = true; // 👈 new flag for auto-follow
  StreamSubscription<Position>? positionStream;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _loadGeoJson();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  /// 🔄 Start continuous location updates
  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        currentLocation = const LatLng(26.8467, 80.9462); // Lucknow fallback
        locationTried = true;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          currentLocation = const LatLng(26.8467, 80.9462);
          locationTried = true;
        });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        currentLocation = const LatLng(26.8467, 80.9462);
        locationTried = true;
      });
      return;
    }

    // 🚶 Live tracking
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position pos) {
      final LatLng newLoc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        currentLocation = newLoc;
        locationTried = true;
        _calculateNearestPoleDistance();
      });

      if (followUser && _mapController.ready) {
        _mapController.move(newLoc, _mapController.camera.zoom);
      }
    });
  }

  /// 📌 Load GeoJSON
  Future<void> _loadGeoJson() async {
    final String data =
        await rootBundle.loadString('assets/lucknow_network.geojson');
    final geojson = json.decode(data);

    List<LatLng> linePoints = [];
    List<Marker> markers = [];
    Map<String, dynamic> poleDetails = {};

    for (var feature in geojson['features']) {
      final geom = feature['geometry'];
      final props = feature['properties'] ?? {};

      if (geom['type'] == 'LineString') {
        List coords = geom['coordinates'];
        linePoints.addAll(coords.map((c) => LatLng(c[1], c[0])));
      } else if (geom['type'] == 'Point') {
        var coord = geom['coordinates'];
        final LatLng poleLatLng = LatLng(coord[1], coord[0]);
        final String poleId = props['id']?.toString() ?? "Unknown";
        final String poleHeight = props['height']?.toString() ?? "N/A";

        poleDetails["$poleLatLng"] = {"id": poleId, "height": poleHeight};

        markers.add(
          Marker(
            point: poleLatLng,
            width: 25,
            height: 25,
            child: GestureDetector(
              onTap: () => _showPoleInfo(context, poleId, poleHeight),
              child: const Icon(Icons.circle, color: Colors.yellow, size: 12),
            ),
          ),
        );
      }
    }

    setState(() {
      cablePoints = linePoints;
      poleMarkers = markers;
      poleData = poleDetails;
      _calculateNearestPoleDistance();
    });
  }

  /// 📌 Show Pole Info Popup
  void _showPoleInfo(BuildContext context, String id, String height) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("OHE Pole: $id"),
        content: Text("Cable Height: $height meters"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  /// 📏 Calculate nearest pole distance
  void _calculateNearestPoleDistance() {
    if (currentLocation == null || poleData.isEmpty) return;

    double minDistance = double.infinity;
    for (String key in poleData.keys) {
      LatLng poleLatLng = LatLng(
        double.parse(key.split(', ')[0].replaceAll('LatLng(', '')),
        double.parse(key.split(', ')[1].replaceAll(')', '')),
      );
      double distance = Geolocator.distanceBetween(
        currentLocation!.latitude,
        currentLocation!.longitude,
        poleLatLng.latitude,
        poleLatLng.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    setState(() => nearestPoleDistance = minDistance);
  }

  @override
  Widget build(BuildContext context) {
    if (!locationTried && currentLocation == null && poleMarkers.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Lucknow OHE Map")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: currentLocation ?? const LatLng(26.8467, 80.9462),
          initialZoom: 13,
          onPositionChanged: (pos, hasGesture) {
            if (hasGesture) {
              // 👈 stop auto-follow if user pans/zooms
              setState(() => followUser = false);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          if (currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: currentLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.my_location,
                      color: Colors.blue, size: 35),
                ),
              ],
            ),
          MarkerLayer(markers: poleMarkers),
          PolylineLayer(
            polylines: [
              Polyline(
                points: cablePoints,
                strokeWidth: 3,
                color: Colors.yellow,
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (currentLocation != null) {
            _mapController.move(currentLocation!, 16); // zoom on user
            setState(() => followUser = true); // resume auto-follow
          }
        },
        child: Icon(followUser ? Icons.gps_fixed : Icons.gps_not_fixed),
      ),
    );
  }
}