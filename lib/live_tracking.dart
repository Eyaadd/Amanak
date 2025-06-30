import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

// Define the primary color to match guardian location
const Color primaryBlue = Color(0xFF015C92);

class LiveTracking extends StatefulWidget {
  static const routeName = "LiveTracking";
  const LiveTracking({super.key});

  @override
  State<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {
  double zoomClose = 18.0;
  final double _minZoom = 10.0;
  final double _maxZoom = 20.0;
  final Completer<GoogleMapController> _controller = Completer();
  StreamSubscription<DocumentSnapshot>? _locationSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;
  String currentLocationName = 'Loading location...';
  String sharedLocationName = 'Loading shared location...';
  User? currentUser;
  bool _isLoading = true;
  String? sharedUserEmail;
  Position? _currentPosition;
  double? sharedUserLat;
  double? sharedUserLng;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return false;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location services are disabled. Please enable the services'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return false;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are denied'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return false;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location permissions are permanently denied, we cannot request permissions.'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      return true;
    } catch (e) {
      print('Error handling location permission: $e');
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error handling location permission: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<void> _initializeTracking() async {
    try {
      await Firebase.initializeApp();
      currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        if (!mounted) return;

        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to use this feature'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Handle location permissions
      _locationPermissionGranted = await _handleLocationPermission();
      if (!mounted) return;

      if (!_locationPermissionGranted) {
        setState(() => _isLoading = false);
        return;
      }

      await _setupLocationTracking();
    } catch (e) {
      print('Error in initialization: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing tracking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setupLocationTracking() async {
    try {
      // Get current user's document to find shared user email
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (!mounted) return;

      if (!userDoc.exists) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User document not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String? sharedEmail = userData['sharedUsers'] as String?;

      if (!mounted) return;

      if (sharedEmail == null || sharedEmail.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No shared user found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Find shared user's document by email
      QuerySnapshot sharedUserQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: sharedEmail)
          .limit(1)
          .get();

      if (!mounted) return;

      if (sharedUserQuery.docs.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared user not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Start tracking both current and shared user locations
      String sharedUserId = sharedUserQuery.docs.first.id;
      setState(() {
        sharedUserEmail = sharedEmail;
      });

      try {
        await Future.wait([
          _startLocationUpdates(),
          _listenToSharedUserLocation(sharedUserId, sharedEmail),
        ]).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        print(
            "Couldn't fetch both locations within 10 seconds. Displaying available data.");
      } catch (e) {
        print("Error waiting for initial location updates: $e");
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error in setup: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting up location tracking: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startLocationUpdates() {
    final completer = Completer<void>();
    _positionStreamSubscription?.cancel();
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
      if (mounted) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        setState(() {
          _currentPosition = position;
        });
        _updateCurrentLocationInFirestore(position);
        _updateLocationName(position.latitude, position.longitude, true);
      }
    }, onError: (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    });
    return completer.future;
  }

  Future<void> _listenToSharedUserLocation(
      String sharedUserId, String sharedEmail) {
    final completer = Completer<void>();
    _locationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(sharedUserId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        if (lat != null && lng != null) {
          if (mounted) {
            if (!completer.isCompleted) {
              completer.complete();
            }
            setState(() {
              sharedUserLat = lat;
              sharedUserLng = lng;
            });
            _updateLocationName(lat, lng, false);
            _animateToSharedUserLocation(lat, lng);
          }
        }
      }
    }, onError: (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    });
    return completer.future;
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

  Future<void> _updateCurrentLocationInFirestore(Position position) async {
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _updateLocationName(
      double lat, double lng, bool isCurrentUser) async {
    final locationName = await _getLocationName(lat, lng);
    if (mounted) {
      setState(() {
        if (isCurrentUser) {
          currentLocationName = locationName;
        } else {
          sharedLocationName = locationName;
        }
      });
    }
  }

  void _animateToSharedUserLocation(double lat, double lng) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: zoomClose),
      ),
    );
  }

  void _zoomMap(bool zoomIn) async {
    try {
      final GoogleMapController controller = await _controller.future;
      double currentZoom = await controller.getZoomLevel();
      double newZoom = zoomIn ? currentZoom + 1 : currentZoom - 1;
      newZoom = math.min(math.max(newZoom, _minZoom), _maxZoom);

      if (_currentPosition != null ||
          (sharedUserLat != null && sharedUserLng != null)) {
        LatLng center;
        if (_currentPosition != null &&
            sharedUserLat != null &&
            sharedUserLng != null) {
          // If both locations are available, zoom on the midpoint
          center = LatLng(
            (_currentPosition!.latitude + sharedUserLat!) / 2,
            (_currentPosition!.longitude + sharedUserLng!) / 2,
          );
        } else if (_currentPosition != null) {
          // If only current location is available
          center =
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        } else {
          // If only shared location is available
          center = LatLng(sharedUserLat!, sharedUserLng!);
        }

        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: center,
              zoom: newZoom,
            ),
          ),
        );

        if (!mounted) return;

        setState(() {
          zoomClose = newZoom;
        });
      }
    } catch (e) {
      print('Error in zoom: $e');
    }
  }

  Future<void> newCameraPosition() async {
    try {
      if (!(_currentPosition != null ||
          (sharedUserLat != null && sharedUserLng != null))) {
        return;
      }

      final GoogleMapController controller = await _controller.future;

      if (_currentPosition != null &&
          sharedUserLat != null &&
          sharedUserLng != null) {
        // If both locations are available, show both with padding
        final double padding = 50.0;
        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(
            math.min(_currentPosition!.latitude, sharedUserLat!),
            math.min(_currentPosition!.longitude, sharedUserLng!),
          ),
          northeast: LatLng(
            math.max(_currentPosition!.latitude, sharedUserLat!),
            math.max(_currentPosition!.longitude, sharedUserLng!),
          ),
        );

        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
      } else {
        // If only one location is available, center on it
        LatLng center = _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : LatLng(sharedUserLat!, sharedUserLng!);

        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: center,
              zoom: zoomClose,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error in camera position: $e');
    }
  }

  Future<void> _openDirections() async {
    try {
      if (_currentPosition == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your location is not available yet. Please wait.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (sharedUserLat == null || sharedUserLng == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared user location is not available yet.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print(
          'Current Position: ${_currentPosition!.latitude},${_currentPosition!.longitude}');
      print('Shared Position: $sharedUserLat,$sharedUserLng');

      // Using a simpler URL format
      final urlString =
          'https://www.google.com/maps/dir/${_currentPosition!.latitude},${_currentPosition!.longitude}/$sharedUserLat,$sharedUserLng';
      print('Attempting to open URL: $urlString');

      final url = Uri.parse(urlString);

      // Check if URL can be launched
      final canLaunch = await canLaunchUrl(url);
      print('Can launch URL: $canLaunch');

      if (canLaunch) {
        // Try to launch with external application mode
        final launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
        print('URL launch result: $launched');

        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to open maps. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Try fallback URL
        final fallbackUrl = Uri.parse(
            'https://www.google.com/maps?q=$sharedUserLat,$sharedUserLng');
        print('Attempting fallback URL: $fallbackUrl');

        final canLaunchFallback = await canLaunchUrl(fallbackUrl);
        print('Can launch fallback URL: $canLaunchFallback');

        if (canLaunchFallback) {
          final launched = await launchUrl(
            fallbackUrl,
            mode: LaunchMode.externalApplication,
          );
          print('Fallback URL launch result: $launched');

          if (!launched && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to open maps. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not open maps application. Please make sure you have Google Maps installed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error opening directions: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToLocation(double lat, double lng) async {
    try {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: zoomClose,
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to location: $e');
    }
  }

  Future<void> _navigateToUserLocation() async {
    if (_currentPosition != null) {
      await _navigateToLocation(
          _currentPosition!.latitude, _currentPosition!.longitude);
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your location is not available yet. Please wait.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToSharedUserLocation() async {
    if (sharedUserLat != null && sharedUserLng != null) {
      await _navigateToLocation(sharedUserLat!, sharedUserLng!);
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shared user location is not available yet.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasCurrentLocation = _currentPosition != null;
    bool hasSharedLocation = sharedUserLat != null && sharedUserLng != null;
    bool showMap = hasCurrentLocation || hasSharedLocation;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Live Location Sharing',
          style: TextStyle(color: primaryBlue),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryBlue),
      ),
      body: _isLoading
          ? loadingContainer()
          : Stack(
              children: <Widget>[
                showMap
                    ? GoogleMap(
                        mapType: MapType.normal,
                        markers: {
                          if (hasCurrentLocation)
                            Marker(
                              position: LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              markerId: const MarkerId('current_location'),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueMagenta,
                              ),
                              infoWindow: InfoWindow(
                                title: 'Your Location',
                                snippet: currentLocationName,
                              ),
                              onTap: () => _navigateToUserLocation(),
                            ),
                          if (hasSharedLocation)
                            Marker(
                              position: LatLng(sharedUserLat!, sharedUserLng!),
                              markerId: const MarkerId('shared_user'),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueBlue,
                              ),
                              infoWindow: InfoWindow(
                                title: 'Shared User Location',
                                snippet: sharedUserEmail,
                              ),
                              onTap: () => _navigateToSharedUserLocation(),
                            ),
                        },
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _currentPosition?.latitude ?? (sharedUserLat ?? 0),
                            _currentPosition?.longitude ?? (sharedUserLng ?? 0),
                          ),
                          zoom: zoomClose,
                        ),
                        onMapCreated: (GoogleMapController controller) {
                          _controller.complete(controller);
                          if (hasCurrentLocation && hasSharedLocation) {
                            newCameraPosition();
                          }
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
                          if (hasCurrentLocation && hasSharedLocation) {
                            newCameraPosition();
                          }
                        },
                        child: const Icon(Icons.refresh, color: primaryBlue),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "myLocation",
                        backgroundColor: Colors.white,
                        onPressed: _navigateToUserLocation,
                        child: const Icon(Icons.person_pin_circle,
                            color: primaryBlue),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 25.h,
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
                    child: showMap
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasCurrentLocation) ...[
                                const Text(
                                  'Your Location',
                                  style: TextStyle(
                                    color: primaryBlue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: primaryBlue,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        currentLocationName,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (hasSharedLocation) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Tracking: ${sharedUserEmail ?? ""}',
                                  style: const TextStyle(
                                    color: primaryBlue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: primaryBlue,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        sharedLocationName,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                                        'Show Both',
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
                                          borderRadius:
                                              BorderRadius.circular(10),
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
                                          borderRadius:
                                              BorderRadius.circular(10),
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
                              'Waiting for location updates...',
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
