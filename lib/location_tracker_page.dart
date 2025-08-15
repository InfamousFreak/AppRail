import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';

class LocationTrackerPage extends StatefulWidget {
  const LocationTrackerPage({super.key});

  @override
  State<LocationTrackerPage> createState() => LocationTrackerPageState();
}

class LocationTrackerPageState extends State<LocationTrackerPage> {
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();

  // NEW: Add a StreamSubscription to manage the location stream
  StreamSubscription<Position>? _positionStreamSubscription;

  // State variables
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(23.6886, 86.9544), // Durgapur
    zoom: 14.0,
  );

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  String _distance = "N/A";
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  bool _showDistancePanel = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    // IMPORTANT: Cancel the stream subscription to save battery
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // MODIFIED: This function now sets up the real-time location stream
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Please enable them.'),
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied, we cannot request permissions.',
          ),
        ),
      );
      return;
    }

    // NEW: Start listening to the position stream
    _positionStreamSubscription = Geolocator.getPositionStream().listen((
      Position position,
    ) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);

        // Update the marker for the current location
        _markers.removeWhere(
          (marker) => marker.markerId.value == 'currentLocation',
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: _currentPosition!,
            infoWindow: const InfoWindow(title: 'My Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );

        // Recalculate distance if a destination is set
        if (_destinationPosition != null) {
          _calculateDistance();
        }
      });

      // Optionally, animate the camera to follow the user
      // _controller.future.then((controller) {
      //   controller.animateCamera(CameraUpdate.newCameraPosition(
      //     CameraPosition(target: _currentPosition!, zoom: 16.0),
      //   ));
      // });
    });
  }

  void _searchAndGetRoute() async {
    // ... (This function remains the same as before)
    try {
      List<Location> locations = await locationFromAddress(
        _searchController.text,
      );
      if (locations.isNotEmpty) {
        final location = locations.first;
        _destinationPosition = LatLng(location.latitude, location.longitude);

        _markers.removeWhere((m) => m.markerId.value == 'destination');
        _polylines.clear();

        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: _destinationPosition!,
            infoWindow: InfoWindow(title: _searchController.text),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );

        _getRoute();

        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                _currentPosition!.latitude < _destinationPosition!.latitude
                    ? _currentPosition!.latitude
                    : _destinationPosition!.latitude,
                _currentPosition!.longitude < _destinationPosition!.longitude
                    ? _currentPosition!.longitude
                    : _destinationPosition!.longitude,
              ),
              northeast: LatLng(
                _currentPosition!.latitude > _destinationPosition!.latitude
                    ? _currentPosition!.latitude
                    : _destinationPosition!.latitude,
                _currentPosition!.longitude > _destinationPosition!.longitude
                    ? _currentPosition!.longitude
                    : _destinationPosition!.longitude,
              ),
            ),
            50.0,
          ),
        );

        setState(() {
          _showDistancePanel = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not find the location. Try being more specific.',
          ),
        ),
      );
    }
  }

  Future<void> _getRoute() async {
    // ... (This function remains the same as before)
    if (_currentPosition == null || _destinationPosition == null) return;

    const String apiKey =
        'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6Ijc1ZTBiNjA5NTE2ODQ2YzU5ODg1ZjAyYzllY2I2ZjcwIiwiaCI6Im11cm11cjY0In0=';
    final String url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${_currentPosition!.longitude},${_currentPosition!.latitude}&end=${_destinationPosition!.longitude},${_destinationPosition!.latitude}';

    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> features = data['features'];
        if (features.isNotEmpty) {
          final List<dynamic> coordinates =
              features[0]['geometry']['coordinates'];
          final List<LatLng> routePoints = coordinates
              .map((coord) => LatLng(coord[1], coord[0]))
              .toList();

          final double distanceInMeters =
              features[0]['properties']['summary']['distance'];

          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: routePoints,
                color: Colors.blue,
                width: 5,
              ),
            );
            _distance = "${(distanceInMeters / 1000).toStringAsFixed(2)} km";
          });
        }
      }
    } catch (e) {
      print(e);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not fetch route.')));
    }
  }

  // NEW: This function is now separate for clarity
  void _calculateDistance() {
    if (_currentPosition == null || _destinationPosition == null) return;

    final double distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _destinationPosition!.latitude,
      _destinationPosition!.longitude,
    );

    setState(() {
      _distance = "${(distanceInMeters / 1000).toStringAsFixed(2)} km";
    });
  }

  @override
  Widget build(BuildContext context) {
    // ... (The build method remains the same as before)
    return Scaffold(
      appBar: AppBar(title: const Text('Location Tracker')),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            padding: EdgeInsets.only(bottom: _showDistancePanel ? 100 : 0),
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 5),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search for a destination...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(left: 15),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchAndGetRoute,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: _showDistancePanel ? 120 : 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () async {
                // The FAB now just animates the camera to the current position
                final GoogleMapController controller = await _controller.future;
                if (_currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: _currentPosition!, zoom: 16.0),
                    ),
                  );
                }
              },
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              child: const Icon(Icons.my_location),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: _showDistancePanel ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Distance to Destination: $_distance',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
