import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class Pole {
  final LatLng point;
  final String id;
  final String height;
  Pole(this.point, {required this.id, required this.height});
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  // Real-time location
  LatLng? _current;
  StreamSubscription<Position>? _posSub;

  // GeoJSON data
  final List<List<LatLng>> _cablePolylines = []; // multiple LineStrings
  final List<Pole> _poles = [];

  // Nearest pole state
  Pole? _nearest;
  double? _nearestMeters;

  // Straight navigation line to nearest pole
  List<LatLng> _navLine = [];

  final Distance _dist = const Distance();

  @override
  void initState() {
    super.initState();
    _ensureLocation();
    _loadGeoJson();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureLocation() async {
    // Services enabled?
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    // Permissions
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    if (perm == LocationPermission.deniedForever) return;

    // Get initial + subscribe stream
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _setCurrent(LatLng(pos.latitude, pos.longitude));

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // update every ~1m
      ),
    ).listen((p) => _setCurrent(LatLng(p.latitude, p.longitude)));
  }

  void _setCurrent(LatLng latLng) {
    setState(() {
      _current = latLng;
    });
    _updateNearest();
  }

  Future<void> _loadGeoJson() async {
    final raw = await rootBundle.loadString('assets/lucknow_network.geojson');
    final data = json.decode(raw);

    // Handle FeatureCollection, Feature, or raw Geometry
    List features;
    if (data['type'] == 'FeatureCollection') {
      features = data['features'];
    } else if (data['type'] == 'Feature') {
      features = [data];
    } else {
      features = [
        {'type': 'Feature', 'geometry': data, 'properties': {}}
      ];
    }

    final List<List<LatLng>> polylines = [];
    final List<Pole> poles = [];

    LatLng toLatLng(List c) => LatLng(c[1] * 1.0, c[0] * 1.0);

    for (final f in features) {
      final geom = f['geometry'];
      final props = (f['properties'] ?? {}) as Map;

      if (geom == null) continue;

      final type = geom['type'] as String;
      switch (type) {
        case 'LineString':
          final coords = (geom['coordinates'] as List)
              .map<LatLng>((c) => toLatLng(c))
              .toList();
          if (coords.length >= 2) polylines.add(coords);
          break;

        case 'MultiLineString':
          final lines = geom['coordinates'] as List;
          for (final line in lines) {
            final coords =
                (line as List).map<LatLng>((c) => toLatLng(c)).toList();
            if (coords.length >= 2) polylines.add(coords);
          }
          break;

        case 'Point':
          final c = geom['coordinates'];
          final id = props['id']?.toString() ?? 'Pole';
          final h = props['height']?.toString() ?? 'NA';
          poles.add(Pole(toLatLng(c), id: id, height: h));
          break;

        default:
          // Ignore other geometry types
          break;
      }
    }

    setState(() {
      _cablePolylines.clear();
      _cablePolylines.addAll(polylines);
      _poles.clear();
      _poles.addAll(poles);
    });

    _updateNearest();
  }

  void _updateNearest() {
    if (_current == null || _poles.isEmpty) {
      setState(() {
        _nearest = null;
        _nearestMeters = null;
        _navLine = [];
      });
      return;
    }

    double best = double.infinity;
    Pole? bestPole;

    for (final p in _poles) {
      final m = _dist.as(LengthUnit.Meter, _current!, p.point);
      if (m < best) {
        best = m;
        bestPole = p;
      }
    }

    setState(() {
      _nearest = bestPole;
      _nearestMeters = best.isFinite ? best : null;
      _navLine = (bestPole == null) ? [] : [_current!, bestPole.point];
    });
  }

  Future<void> _openGoogleMapsToNearest() async {
    if (_current == null || _nearest == null) return;
    final s = '${_current!.latitude},${_current!.longitude}';
    final d = '${_nearest!.point.latitude},${_nearest!.point.longitude}';
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$s&destination=$d&travelmode=walking');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lucknow default center if GPS not ready yet
    final initial = _current ?? const LatLng(26.8467, 80.9462);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lucknow Railway Map'),
        actions: [
          IconButton(
            onPressed: _openGoogleMapsToNearest,
            tooltip: 'Open in Google Maps',
            icon: const Icon(Icons.directions_walk),
          )
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initial,
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),

          // CABLES (yellow lines)
          PolylineLayer(
            polylines: _cablePolylines
                .map((line) => Polyline(
                      points: line,
                      strokeWidth: 3,
                      color: Colors.yellow,
                    ))
                .toList(),
          ),

          // OHE POLES (yellow dots, tappable)
          MarkerLayer(
            markers: _poles
                .map(
                  (p) => Marker(
                    point: p.point,
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Pole: ${p.id}'),
                            content: Text('Height: ${p.height} m'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              )
                            ],
                          ),
                        );
                      },
                      child: const Icon(Icons.circle,
                          size: 10, color: Colors.yellow),
                    ),
                  ),
                )
                .toList(),
          ),

          // USER location (blue dot)
          if (_current != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _current!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.my_location,
                      color: Colors.blue, size: 36),
                ),
              ],
            ),

          // NAVIGATION line (to nearest pole)
          if (_navLine.length == 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _navLine,
                  strokeWidth: 4,
                  color: Colors.red,
                  isDotted: true,
                ),
              ],
            ),
        ],
      ),

      // HUD: distance to nearest pole
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.sensor_door, color: Colors.yellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (_nearest != null && _nearestMeters != null)
                      ? 'Nearest Pole: ${_nearest!.id} • ${_nearestMeters!.toStringAsFixed(1)} m • Height: ${_nearest!.height} m'
                      : 'Finding nearest pole…',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              IconButton(
                onPressed: _openGoogleMapsToNearest,
                icon: const Icon(Icons.directions_walk, color: Colors.white),
                tooltip: 'Navigate',
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // recenter on current
          if (_current != null) {
            _mapController.move(_current!, 16);
          } else {
            await _ensureLocation();
          }
        },
        child: const Icon(Icons.gps_fixed),
      ),
    );
  }
}
