import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Define the primary color to match guardian location
const Color primaryBlue = Color(0xFF015C92);

class LiveTracking extends StatefulWidget {
  const LiveTracking({super.key});

  @override
  State<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {
  double zoomClose = 18.0;
  final double _minZoom = 10.0;
  final double _maxZoom = 20.0;
  Completer<GoogleMapController> _controller = Completer();
  StreamSubscription<DocumentSnapshot>? _locationSubscription;
  LocationData? _guardianLocation;
  String guardianLocationName = 'Loading location...';

  // Temporary hardcoded guardian ID - replace this with actual ID later
  final String hardcodedGuardianId = 'S3DISpEHtWUTQ1OkJVyFKa9LnBy1';

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp();
    listenToGuardianLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
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

    if (_guardianLocation != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
                _guardianLocation!.latitude, _guardianLocation!.longitude),
            zoom: zoomClose,
          ),
        ),
      );
    }
  }

  void listenToGuardianLocation() {
    _locationSubscription = FirebaseFirestore.instance
        .collection('amanak_location')
        .doc(hardcodedGuardianId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final newLat = data['latitude'] ?? 0.0;
        final newLng = data['longitude'] ?? 0.0;

        final locationName = await _getLocationName(newLat, newLng);
        setState(() {
          _guardianLocation = LocationData(
            latitude: newLat,
            longitude: newLng,
          );
          guardianLocationName = locationName;
        });
        newCameraPosition();
      }
    }, onError: (error) {
      print('Error listening to guardian location: $error');
    });
  }

  Future<void> newCameraPosition() async {
    if (_guardianLocation != null) {
      final GoogleMapController controller = await _controller.future;
      controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(
          _guardianLocation!.latitude,
          _guardianLocation!.longitude,
        ),
        zoom: zoomClose,
      )));
    }
  }

  Future<void> _openDirections() async {
    if (_guardianLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get guardian location. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${_guardianLocation!.latitude},${_guardianLocation!.longitude}&travelmode=driving',
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

  @override
  Widget build(BuildContext context) {
    bool conditionMap = _guardianLocation?.latitude != null &&
        _guardianLocation?.longitude != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Guardian Location',
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
                position: LatLng(
                  _guardianLocation!.latitude,
                  _guardianLocation!.longitude,
                ),
                markerId: const MarkerId('guardian'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
                infoWindow: InfoWindow(
                  title: 'Guardian Location',
                  snippet: guardianLocationName,
                ),
              ),
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _guardianLocation!.latitude,
                _guardianLocation!.longitude,
              ),
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
              height: 20.h,
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
                    'Guardian Location',
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
                          guardianLocationName,
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
                            newCameraPosition();
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
                  'Getting guardian location...',
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

class LocationData {
  final double latitude;
  final double longitude;

  LocationData({
    required this.latitude,
    required this.longitude,
  });
}
