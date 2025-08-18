import 'dart:convert';
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
  Map<String, dynamic> poleData = {}; // Pole info store karega

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadGeoJson();
  }

  /// 📍 Get current GPS location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('GPS service disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('GPS permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('GPS permission permanently denied');
    }

    Position pos =
        await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      currentLocation = LatLng(pos.latitude, pos.longitude);
    });
  }

  /// 📌 Load merged Lucknow GeoJSON
  Future<void> _loadGeoJson() async {
    final String data =
        await rootBundle.loadString('assets/lucknow_network.geojson');
    final geojson = json.decode(data);

    List<LatLng> linePoints = [];
    List<Marker> markers = {};
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

        poleDetails["$poleLatLng"] = {
          "id": poleId,
          "height": poleHeight,
        };

        markers.add(
          Marker(
            point: poleLatLng,
            width: 25,
            height: 25,
            child: GestureDetector(
              onTap: () {
                _showPoleInfo(context, poleId, poleHeight);
              },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lucknow OHE Map")),
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(26.8467, 80.9462), // Lucknow
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),

                /// 📍 User GPS Marker
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.my_location,
                          color: Colors.blue, size: 35),
                    ),
                    ...poleMarkers, // Yellow OHE Poles
                  ],
                ),

                /// 📏 Cables Polyline
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
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.gps_fixed),
      ),
    );
  }
}
