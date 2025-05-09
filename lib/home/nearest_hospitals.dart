import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class NearestHospitals extends StatefulWidget {
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

  @override
  void initState() {
    super.initState();
    _fetchLocationAndHospitals();
  }

  Future<void> _fetchLocationAndHospitals() async {
    try {
      final locData = await _location.getLocation();
      final latLng = LatLng(locData.latitude!, locData.longitude!);

      setState(() {
        _currentLocation = latLng;
      });

      await _getNearbyHospitals();
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  Future<void> _getNearbyHospitals() async {
    if (_currentLocation == null) return;

    const radius = 5000;
    final lat = _currentLocation!.latitude;
    final lng = _currentLocation!.longitude;
    const apiKey = 'AIzaSyBtPvYgEr-gpBs4FoN2ucSbzrqzsCg4nMs'; // 🔒 Replace with your actual key

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
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      }

      setState(() {
        _markers = newMarkers;
        _hospitals = newHospitals;
      });
    } else {
      print('Failed to fetch nearby hospitals: ${data['status']}');
    }
  }

  Future<void> _moveToHospital(LatLng location) async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: location, zoom: 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearest Hospitals"),
        centerTitle: true,
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation!,
              zoom: 14,
            ),
            markers: _markers,
            onMapCreated: (controller) => _controller.complete(controller),
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: _hospitals.isEmpty
                  ? const Center(child: CircularProgressIndicator())
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
      ),
    );
  }
}
