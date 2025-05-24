import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

// Define the primary color to match nearest hospitals
const Color primaryBlue = Color(0xFF015C92);

class GuardianLiveTracking extends StatefulWidget {
  const GuardianLiveTracking({super.key});
  static const routeName = "_GuardianLiveTrackingState";

  @override
  State<GuardianLiveTracking> createState() => _GuardianLiveTrackingState();
}

class _GuardianLiveTrackingState extends State<GuardianLiveTracking> {
  double zoomClose = 18.0;
  final double _minZoom = 10.0;
  final double _maxZoom = 20.0;
  Completer<GoogleMapController> _controller = Completer();
  final Location _location = Location();

  // For showing elderly's location
  late double elderlyLatitude = 0.0;
  late double elderlyLongitude = 0.0;
  String elderlyLocationName = 'Loading location...';

  // For guardian's location
  late double guardianLatitude = 0.0;
  late double guardianLongitude = 0.0;

  // Replace this with the elderly's userId
  final String elderlyUserId = 'S3DISpEHtWUTQ1OkJVyFKa9LnBy1';

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp();
    _getCurrentLocation();
    listenForElderlyLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationData = await _location.getLocation();
      setState(() {
        guardianLatitude = locationData.latitude!;
        guardianLongitude = locationData.longitude!;
      });
    } catch (e) {
      print("Error getting current location: $e");
    }
  }

  Future<String> _getLocationName(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=AIzaSyBtPvYgEr-gpBs4FoN2ucSbzrqzsCg4nMs',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          // Get the formatted address from the first result
          return data['results'][0]['formatted_address'];
        }
      }
      return 'Location not found';
    } catch (e) {
      print("Error getting location name: $e");
      return 'Error getting location';
    }
  }

  void _zoomMap(bool zoomIn) async {
    final GoogleMapController controller = await _controller.future;
    double newZoom = zoomIn ? zoomClose + 1 : zoomClose - 1;
    newZoom = math.min(math.max(newZoom, _minZoom), _maxZoom);

    setState(() {
      zoomClose = newZoom;
    });

    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(elderlyLatitude, elderlyLongitude),
          zoom: zoomClose,
        ),
      ),
    );
  }

  Future<void> _openDirections() async {
    if (guardianLatitude == 0.0 || elderlyLatitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get locations. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$guardianLatitude,$guardianLongitude&destination=$elderlyLatitude,$elderlyLongitude&travelmode=driving',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open directions'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void listenForElderlyLocation() {
    FirebaseFirestore.instance
        .collection('amanak_location')
        .doc(elderlyUserId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final newLat = snapshot['latitude'];
        final newLng = snapshot['longitude'];

        if (newLat != elderlyLatitude || newLng != elderlyLongitude) {
          final locationName = await _getLocationName(newLat, newLng);
          setState(() {
            elderlyLatitude = newLat;
            elderlyLongitude = newLng;
            elderlyLocationName = locationName;
          });
          updateMapToElderlyLocation();
        }
      } else {
        print("Elderly's location not available in Firestore.");
      }
    });
  }

  // Update map's camera to show the elderly's location
  Future<void> updateMapToElderlyLocation() async {
    final GoogleMapController controller = await _controller.future;
    controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(elderlyLatitude, elderlyLongitude),
      zoom: zoomClose,
    )));
  }

  @override
  Widget build(BuildContext context) {
    bool conditionMap = elderlyLatitude != 0.0 && elderlyLongitude != 0.0;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Elderly Live Tracking',
          style: TextStyle(color: primaryBlue),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryBlue),
      ),
      body: Stack(
        children: <Widget>[
          conditionMap
              ? GoogleMap(
            mapType: MapType.normal,
            markers: {
              Marker(
                position: LatLng(elderlyLatitude, elderlyLongitude),
                markerId: const MarkerId('elderlyLocation'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
                infoWindow: InfoWindow(
                    title: 'Elderly Location',
                    snippet: elderlyLocationName),
              ),
              if (guardianLatitude != 0.0)
                Marker(
                  position: LatLng(guardianLatitude, guardianLongitude),
                  markerId: const MarkerId('guardianLocation'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                  infoWindow: const InfoWindow(title: 'Your Location'),
                ),
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(elderlyLatitude, elderlyLongitude),
              zoom: zoomClose,
            ),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          )
              : loadingContainer(),
          // Zoom and refresh controls
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.2,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "zoomIn",
                  backgroundColor: Colors.white,
                  onPressed: () => _zoomMap(true),
                  child: const Icon(Icons.add, color: primaryBlue),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "zoomOut",
                  backgroundColor: Colors.white,
                  onPressed: () => _zoomMap(false),
                  child: const Icon(Icons.remove, color: primaryBlue),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "refresh",
                  backgroundColor: Colors.white,
                  onPressed: () {
                    setState(() {});
                    _getCurrentLocation();
                  },
                  child: const Icon(Icons.refresh, color: primaryBlue),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 20.h, // Reduced height since we have less content
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: conditionMap
                  ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Elderly Location',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          elderlyLocationName,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            updateMapToElderlyLocation();
                          },
                          icon: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Center Map',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openDirections,
                          icon: const Icon(
                            Icons.directions,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Directions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
                  : const Center(
                child: Text(
                  'Getting the elderly location...',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget loadingContainer() {
    return Container(
      color: Colors.white,
      height: 100.h,
      width: 100.w,
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Loading Map...",
              style: TextStyle(
                color: primaryBlue,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4.h),
            const CupertinoActivityIndicator(
              color: primaryBlue,
            ),
          ],
        ),
      ),
    );
  }
}
