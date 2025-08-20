import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart' show rootBundle;

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  LatLng? _currentPosition;
  String _searchQuery = "";
  Marker? _selectedMast;

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
    _getCurrentLocation();
  }

  Future<void> _loadGeoJson() async {
    final String data =
        await rootBundle.loadString('assets/geojson/lucknow_network.geojson');
    final geojson = json.decode(data);

    List<Marker> markers = [];
    List<Polyline> polylines = [];

    for (var feature in geojson["features"]) {
      if (feature["geometry"]["type"] == "Point") {
        var coords = feature["geometry"]["coordinates"];
        var name = feature["properties"]["name"] ?? "OHE Mast";

        markers.add(Marker(
          width: 80.0,
          height: 80.0,
          point: LatLng(coords[1], coords[0]),
          builder: (ctx) => Icon(Icons.location_on, color: Colors.red),
        ));
      }

      if (feature["geometry"]["type"] == "LineString") {
        var coords = feature["geometry"]["coordinates"];
        List<LatLng> points = [];
        for (var c in coords) {
          points.add(LatLng(c[1], c[0]));
        }

        polylines.add(Polyline(
          points: points,
          strokeWidth: 3.0,
          color: Colors.yellow,
        ));
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    });
  }

  void _searchMast(String query) {
    setState(() {
      _searchQuery = query;
      _selectedMast = null;
    });

    for (var marker in _markers) {
      if (marker.builder != null && query.isNotEmpty) {
        // Check if mast name matches query
        if ((marker.key?.toString() ?? "").contains(query)) {
          setState(() {
            _selectedMast = marker;
          });
          _mapController.move(marker.point, 17); // Auto zoom to mast
          break;
        }
      }
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    final Distance distance = Distance();
    return distance.as(LengthUnit.Meter, p1, p2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Lucknow OHE Map"),
        backgroundColor: Colors.red,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(26.8467, 80.9462), // Lucknow center
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
              if (_currentPosition != null)
                CurrentLocationLayer(),
            ],
          ),
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Card(
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search Mast No. (e.g. 762/25)",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10),
                  suffixIcon: Icon(Icons.search),
                ),
                onSubmitted: _searchMast,
              ),
            ),
          ),
          if (_selectedMast != null && _currentPosition != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    "Distance to Mast: ${_calculateDistance(_currentPosition!, _selectedMast!.point).toStringAsFixed(2)} meters",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
