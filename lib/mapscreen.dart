import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<void> _loadDataFuture;

  List<LatLng> linePoints = [];
  List<Marker> markers = [];
  Map<String, dynamic> poleDetails = {};

  @override
  void initState() {
    super.initState();
    _loadDataFuture = _loadGeoJson();
  }

  Future<void> _loadGeoJson() async {
    final data = await rootBundle.loadString("assets/lucknow_network.geojson");
    final geojson = json.decode(data);

    linePoints.clear();
    markers.clear();
    poleDetails.clear();

    for (var feature in geojson['features']) {
      final geometry = feature['geometry'];
      final properties = feature['properties'];

      if (geometry['type'] == 'LineString') {
        final coords = geometry['coordinates'] as List;
        for (var coord in coords) {
          linePoints.add(LatLng(coord[1], coord[0]));
        }
      }

      if (geometry['type'] == 'Point') {
        final coord = geometry['coordinates'];
        final lat = coord[1];
        final lng = coord[0];

        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 40,
            height: 40,
            builder: (ctx) => const Icon(Icons.location_on, color: Colors.red),
          ),
        );

        poleDetails["$lat,$lng"] = properties;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _loadDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // show spinner while loading
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // show map after loading
          return FlutterMap(
            options: MapOptions(
              intialcenter: LatLng(26.8467, 80.9462), // Lucknow center
              zoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(points: linePoints, strokeWidth: 4.0, color: Colors.blue),
                ],
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }
}