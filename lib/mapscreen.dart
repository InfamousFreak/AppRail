import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ✅ Define marker list properly
  final List<Marker> markers = [
    Marker(
      width: 40.0,
      height: 40.0,
      point: LatLng(26.8467, 80.9462), // Lucknow
      child: const Icon(
        Icons.location_on,
        color: Colors.red,
        size: 40,
      ),
    ),
  ];

  // ✅ Define polyline points if needed
  final List<LatLng> linePoints = [
    LatLng(26.8467, 80.9462),
    LatLng(26.9, 80.95),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map Screen")),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(26.8467, 80.9462), // ✅ New API
          initialZoom: 12.0,                       // ✅ New API
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: linePoints,
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}