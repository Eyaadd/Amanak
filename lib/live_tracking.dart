import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Authentication

class LiveTracking extends StatefulWidget {
  const LiveTracking({super.key});

  @override
  State<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {
  double zoomClose = 18.0;
  Completer<GoogleMapController> _controller = Completer();
  Location location = Location();
  bool _serviceEnabled = false;
  late PermissionStatus _permissionGranted;
  late LocationData? _locationData = LocationData.fromMap({
    "latitude": 0.0,
    "longitude": 0.0,
  });

  @override
  void initState() {
    super.initState();
    checkLocationPermission();
    Firebase.initializeApp();  // Initialize Firebase here
  }

  Future<void> checkLocationPermission() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    location.onLocationChanged.listen((LocationData currentLocation) {
      print('Location Changed: Lat: ${currentLocation.latitude}, Lon: ${currentLocation.longitude}');  // Debugging line
      setState(() {
        _locationData = currentLocation;
      });

      // Upload location data to Firestore
      uploadLocationToFirestore(currentLocation);

      newCameraPosition();
    });
  }

  // Upload location to Firestore
  void uploadLocationToFirestore(LocationData locationData) async {
    try {
      // Get the current user's UID
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userId = user.uid;  // Use the UID of the authenticated user

        // Upload location data to Firestore under the user's UID
        await FirebaseFirestore.instance.collection('amanak_location').doc(userId).set({
          'latitude': locationData.latitude,
          'longitude': locationData.longitude,
          'timestamp': FieldValue.serverTimestamp(), // Save current timestamp
        });
      } else {
        print('No user is signed in!');
      }
    } catch (e) {
      print('Error uploading location: $e');
    }
  }

  Future<void> newCameraPosition() async {
    final GoogleMapController controller = await _controller.future;
    controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(
          _locationData?.latitude ?? 0.0,
          _locationData?.longitude ?? 0.0,
        ),
        zoom: zoomClose)));
  }

  @override
  Widget build(BuildContext context) {
    bool conditionMap =
        _locationData?.latitude != 0.0 && _locationData?.longitude != 0.0;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Live Tracking'),
      ),
      body: Stack(
        children: <Widget>[
          conditionMap
              ? GoogleMap(
            mapType: MapType.normal,
            markers: conditionMap
                ? {
              Marker(
                position: LatLng(
                  _locationData?.latitude ?? 0.0,
                  _locationData?.longitude ?? 0.0,
                ),
                markerId: MarkerId('id'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueMagenta,
                ),
              ),
            }
                : {},
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _locationData?.latitude ?? 0.0,
                _locationData?.longitude ?? 0.0,
              ),
              zoom: zoomClose,
            ),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          )
              : loadingContainer(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 20.h,
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border.all(color: Colors.black12, width: 1.5)),
              child: conditionMap
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Latitude: ${_locationData?.latitude}',
                      style: TextStyle(color: Colors.black, fontSize: 18.0),
                    ),
                    SizedBox(
                      height: 2.0,
                    ),
                    Text(
                      'Longitude: ${_locationData?.longitude}',
                      style: TextStyle(color: Colors.black, fontSize: 18.0),
                    ),
                  ],
                ),
              )
                  : Center(child: const Text('Getting the location...')),
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                height: 30.h,
              ),
              const Text("Loading..."),
              SizedBox(
                height: 4.h,
              ),
              CupertinoActivityIndicator()
            ],
          )),
    );
  }
}
