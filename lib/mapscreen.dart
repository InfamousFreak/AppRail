import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<Marker> _oheMarkers = [];
  List<Polyline> _cablePolylines = [];
  LatLng? _userLocation;
  String _distanceText = "";
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
    _getUserLocation();
  }

  Future<void> _loadGeoJson() async {
    final String data =
        await rootBundle.loadString('assets/geojson/lucknow_network.geojson');
    final jsonResult = json.decode(data);

    List<Marker> markers = [];
    List<Polyline> polylines = [];

    for (var feature in jsonResult['features']) {
      if (feature['geometry']['type'] == 'Point') {
        final coords = feature['geometry']['coordinates'];
        final properties = feature['properties'];

        String mastNo = properties['mast_no']?.toString() ??
            properties['name']?.toString() ??
            properties['id']?.toString() ??
            "Unknown";

        markers.add(
          Marker(
            point: LatLng(coords[1], coords[0]),
            width: 80,
            height: 80,
            builder: (ctx) => Column(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 35),
                Text(mastNo,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      } else if (feature['geometry']['type'] == 'LineString') {
        final coords = feature['geometry']['coordinates'] as List;
        polylines.add(
          Polyline(
            points: coords.map((c) => LatLng(c[1], c[0])).toList(),
            strokeWidth: 4.0,
            color: Colors.yellow,
          ),
        );
      }
    }

    setState(() {
      _oheMarkers = markers;
      _cablePolylines = polylines;
    });

    // auto zoom to fit all poles
    if (markers.isNotEmpty) {
      var bounds = LatLngBounds();
      for (var m in markers) {
        bounds.extend(m.point);
      }
      _mapController.fitBounds(bounds);
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _updateNearestDistance();
      });
    });
  }

  void _updateNearestDistance() {
    if (_userLocation == null || _oheMarkers.isEmpty) return;

    final distanceCalc = Distance();
    double minDist = double.infinity;

    for (var marker in _oheMarkers) {
      final d =
          distanceCalc(_userLocation!, marker.point); // meters
      if (d < minDist) minDist = d;
    }

    setState(() {
      _distanceText = "Nearest OHE Pole: ${(minDist / 1000).toStringAsFixed(2)} km";
    });
  }

  void _searchMast(String query) {
    final marker = _oheMarkers.firstWhere(
        (m) => (m.builder(context) as Column)
            .children
            .whereType<Text>()
            .any((t) => t.data == query),
        orElse: () => Marker(
            point: LatLng(0, 0),
            width: 0,
            height: 0,
            builder: (ctx) => Container()));

    if (marker.point.latitude != 0) {
      _mapController.move(marker.point, 17); // zoom into searched mast

      if (_userLocation != null) {
        final distanceCalc = Distance();
        final d = distanceCalc(_userLocation!, marker.point);
        setState(() {
          _distanceText =
              "Mast $query is ${(d / 1000).toStringAsFixed(2)} km away";
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Mast $query not found in map")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Railway OHE Map - Lucknow"),
        backgroundColor: Colors.red,
      ),
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
                        border: OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    _searchMast(_searchController.text.trim());
                  },
                )
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(26.8467, 80.9462), // Lucknow center
                initialZoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),
                PolylineLayer(polylines: _cablePolylines),
                MarkerLayer(markers: _oheMarkers),
                if (_userLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _userLocation!,
                        width: 60,
                        height: 60,
                        builder: (ctx) => const Icon(Icons.my_location,
                            color: Colors.blue, size: 40),
                      )
                    ],
                  )
              ],
            ),
          ),
          if (_distanceText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_distanceText,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }
}
