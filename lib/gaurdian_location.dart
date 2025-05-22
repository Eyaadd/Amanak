import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class GuardianLiveTracking extends StatefulWidget {
  const GuardianLiveTracking({super.key});
  static const routeName = "_GuardianLiveTrackingState";

  @override
  State<GuardianLiveTracking> createState() => _GuardianLiveTrackingState();
}

class _GuardianLiveTrackingState extends State<GuardianLiveTracking> {
  double zoomClose = 18.0;
  Completer<GoogleMapController> _controller = Completer();

  // For showing elderly's location
  late double elderlyLatitude = 0.0;
  late double elderlyLongitude = 0.0;

  // Replace this with the elderly's userId (e.g., from Firebase Authentication or another source)
  final String elderlyUserId = 'a';  // Example elderly ID

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp();  // Initialize Firebase here
    listenForElderlyLocation(); // Listen to the elderly's location from Firestore
  }

  // Listen to the location changes of the elderly in Firestore
  void listenForElderlyLocation() {
    FirebaseFirestore.instance
        .collection('amanak_location')  // Collection name is 'amanak_location'
        .doc(elderlyUserId)  // Document ID of the elderly user
        .snapshots()  // Listen to real-time updates for this document
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          elderlyLatitude = snapshot['latitude'];
          elderlyLongitude = snapshot['longitude'];
        });
        updateMapToElderlyLocation();
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
        title: const Text('Elderly Live Tracking'),
      ),
      body: Stack(
        children: <Widget>[
          conditionMap
              ? GoogleMap(
            mapType: MapType.normal,
            markers: {
              Marker(
                position: LatLng(elderlyLatitude, elderlyLongitude),
                markerId: MarkerId('elderlyLocation'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueMagenta,
                ),
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
                      'Elderly Latitude: $elderlyLatitude',
                      style: TextStyle(color: Colors.black, fontSize: 18.0),
                    ),
                    SizedBox(
                      height: 2.0,
                    ),
                    Text(
                      'Elderly Longitude: $elderlyLongitude',
                      style: TextStyle(color: Colors.black, fontSize: 18.0),
                    ),
                  ],
                ),
              )
                  : Center(child: const Text('Getting the elderly location...')),
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
        ),
      ),
    );
  }
}
