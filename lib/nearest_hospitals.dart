import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class NearestHospitals extends StatefulWidget {
  static const String routeName = "NearestHospitals";
  const NearestHospitals({super.key});

  @override
  State<NearestHospitals> createState() => _NearestHospitalsState();
}

class _NearestHospitalsState extends State<NearestHospitals> {
  final Completer<GoogleMapController> _controller = Completer();
  final Location _location = Location();
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _hospitals = [];
  String _errorMessage = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initLocationService();
  }

  Future<void> _initLocationService() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          setState(() {
            _errorMessage = 'Location services are disabled';
            _isLoading = false;
          });
          return;
        }
      }

      // Check for location permissions
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          setState(() {
            _errorMessage = 'Location permissions are denied';
            _isLoading = false;
          });
          return;
        }
      }

      // Proceed with fetching location and hospitals
      await _fetchLocationAndHospitals();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing location: ${e.toString()}';
        _isLoading = false;
      });
      print("Location initialization error: $e");
    }
  }

  Future<void> _fetchLocationAndHospitals() async {
    try {
      final locData = await _location.getLocation();

      if (locData.latitude == null || locData.longitude == null) {
        setState(() {
          _errorMessage = 'Could not get location coordinates';
          _isLoading = false;
        });
        return;
      }

      final latLng = LatLng(locData.latitude!, locData.longitude!);

      setState(() {
        _currentLocation = latLng;
      });

      await _getNearbyHospitals();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching location: ${e.toString()}';
        _isLoading = false;
      });
      print("Error fetching location: $e");
    }
  }

  Future<void> _getNearbyHospitals() async {
    if (_currentLocation == null) return;

    try {
      const radius = 5000;
      final lat = _currentLocation!.latitude;
      final lng = _currentLocation!.longitude;
      const apiKey = 'AIzaSyBtPvYgEr-gpBs4FoN2ucSbzrqzsCg4nMs';

      final url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=$radius&type=hospital&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final List results = data['results'];
        Set<Marker> newMarkers = {};
        List<Map<String, dynamic>> newHospitals = [];

        for (var place in results) {
          final name = place['name'];
          final loc = place['geometry']['location'];
          final placeId = place['place_id'];
          final latLng = LatLng(loc['lat'], loc['lng']);

          newHospitals.add({'name': name, 'location': latLng});

          newMarkers.add(
            Marker(
              markerId: MarkerId(placeId),
              position: latLng,
              infoWindow: InfoWindow(title: name),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
            ),
          );
        }

        setState(() {
          _markers = newMarkers;
          _hospitals = newHospitals;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch nearby hospitals: ${data['status']}';
          _isLoading = false;
        });
        print('Failed to fetch nearby hospitals: ${data['status']}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching hospitals: ${e.toString()}';
        _isLoading = false;
      });
      print("Error fetching hospitals: $e");
    }
  }

  Future<void> _moveToHospital(LatLng location) async {
    try {
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 16),
      ));
    } catch (e) {
      print("Error moving map: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearest Hospitals"),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  _initLocationService();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentLocation == null) {
      return const Center(child: Text("Unable to get your location"));
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentLocation!,
            zoom: 14,
          ),
          markers: _markers,
          onMapCreated: (controller) {
            if (!_controller.isCompleted) {
              _controller.complete(controller);
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: _hospitals.isEmpty
                ? const Center(child: Text("No hospitals found nearby"))
                : ListView.builder(
                    itemCount: _hospitals.length,
                    itemBuilder: (context, index) {
                      final hospital = _hospitals[index];
                      return ListTile(
                        title: Text(hospital['name']),
                        onTap: () => _moveToHospital(hospital['location']),
                        trailing: const Icon(Icons.location_on),
                      );
                    },
                  ),
          ),
        )
      ],
    );
  }
}
