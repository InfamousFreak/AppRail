import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Future<List<LatLng>> loadGeoJson() async {
    try {
      final data = await rootBundle.loadString('assets/railway_track.geojson');
      final jsonResult = json.decode(data);

      List<LatLng> points = [];
      for (var feature in jsonResult['features']) {
        if (feature['geometry']['type'] == 'LineString') {
          for (var coord in feature['geometry']['coordinates']) {
            points.add(LatLng(coord[1], coord[0]));
          }
        }
      }
      return points;
    } catch (e) {
      print("Error loading geojson: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Railway Map")),
      body: FutureBuilder<List<LatLng>>(
        future: loadGeoJson(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // ✅ Always show map (spinner issue fixed)
          List<LatLng> linePoints = snapshot.data ?? [];

          // Example marker at Lucknow
          final markers = [
            Marker(
              width: 40.0,
              height: 40.0,
              point: LatLng(26.8467, 80.9462),
              builder: (ctx) => const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40,
              ),
            ),
          ];

          return FlutterMap(
            options: MapOptions(
              intialcenter: LatLng(26.8467, 80.9462), // Lucknow
              intialzoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
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
          );
        },
      ),
    );
  }
}
