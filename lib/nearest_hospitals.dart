import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class NearestHospitals extends StatefulWidget {
  static const routeName = "NearestHospitals";
  const NearestHospitals({Key? key}) : super(key: key);

  @override
  State<NearestHospitals> createState() => _NearestHospitalsState();
}

class _NearestHospitalsState extends State<NearestHospitals> {
  final Completer<GoogleMapController> _controller = Completer();
  final Location _location = Location();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _filteredHospitals = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRefreshing = false;

  static const Color primaryBlue = Color(0xFF015C92);
  double _currentZoom = 14.0;
  static const double _minZoom = 10.0;
  static const double _maxZoom = 18.0;

  @override
  void initState() {
    super.initState();
    _fetchLocationAndHospitals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationAndHospitals() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final locData = await _location.getLocation();
      final latLng = LatLng(locData.latitude!, locData.longitude!);
      setState(() {
        _currentLocation = latLng;
      });

      await _addUserMarker();
      await _getNearbyHospitals();
    } catch (e) {
      setState(() {
        _errorMessage =
        'Failed to get location. Please check your location settings.';
      });
      print("Error fetching location: $e");
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _moveToLocation(LatLng location) async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: location, zoom: _currentZoom),
    ));
  }

  Future<void> _launchDirections(LatLng destination) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${_currentLocation!.latitude},${_currentLocation!.longitude}&destination=${destination.latitude},${destination.longitude}&travelmode=driving',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _zoomMap(bool zoomIn) async {
    try {
      final controller = await _controller.future;
      final newZoom = zoomIn
          ? math.min(_currentZoom + 1, _maxZoom)
          : math.max(_currentZoom - 1, _minZoom);

      print('Zooming from $_currentZoom to $newZoom'); // Debug log

      setState(() {
        _currentZoom = newZoom;
      });

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation ?? const LatLng(0, 0),
            zoom: _currentZoom,
          ),
        ),
      );
    } catch (e) {
      print('Error during zoom: $e'); // Debug log
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    var p = 0.017453292519943295; // Math.PI / 180
    var c = math.cos;
    var a = 0.5 -
        c((point2.latitude - point1.latitude) * p) / 2 +
        c(point1.latitude * p) *
            c(point2.latitude * p) *
            (1 - c((point2.longitude - point1.longitude) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  void _filterHospitals(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredHospitals = List.from(_hospitals);
      } else {
        final searchTerms = query.toLowerCase().split(' ');
        _filteredHospitals = _hospitals.where((hospital) {
          final name = hospital['name'].toString().toLowerCase();
          final address = (hospital['address'] ?? '').toString().toLowerCase();

          // Match if all search terms are found in either name or address
          return searchTerms
              .every((term) => name.contains(term) || address.contains(term));
        }).toList();
      }
    });
  }

  Future<void> _addUserMarker() async {
    if (_currentLocation == null) return;

    final Marker userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: _currentLocation!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: 'Your Location'),
    );

    setState(() {
      _markers.add(userMarker);
    });
  }

  Future<void> _getNearbyHospitals() async {
    if (_currentLocation == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First search with a smaller radius
      await _fetchHospitalsWithRadius(5000); // 5km

      // If we don't have enough results, try with a larger radius
      if (_hospitals.length < 10) {
        await _fetchHospitalsWithRadius(15000); // 15km
      }

      // If still not enough, go even larger
      if (_hospitals.length < 20) {
        await _fetchHospitalsWithRadius(30000); // 30km
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _hospitals.isEmpty
            ? 'No hospitals found in your area. Please try again.'
            : null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
        'Error loading hospitals. Please check your internet connection.';
      });
      print('Error fetching hospitals: $e');
    }
  }

  Future<void> _fetchHospitalsWithRadius(int radius) async {
    final lat = _currentLocation!.latitude;
    final lng = _currentLocation!.longitude;
    const apiKey = 'AIzaSyBtPvYgEr-gpBs4FoN2ucSbzrqzsCg4nMs';
    String? nextPageToken;
    Set<String> existingPlaceIds =
    _hospitals.map((h) => h['place_id'] as String).toSet();

    // Keep existing markers and add new ones
    Set<Marker> newMarkers = Set.from(_markers);
    List<Map<String, dynamic>> newHospitals = List.from(_hospitals);

    try {
      do {
        final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
                '?location=$lat,$lng'
                '&radius=$radius'
                '&type=hospital'
                '&keyword=hospital|medical center|clinic|emergency'
                '&key=$apiKey'
                '${nextPageToken != null ? '&pagetoken=$nextPageToken' : ''}');

        final response = await http.get(url);
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final List results = data['results'];
          nextPageToken = data['next_page_token'];

          for (var place in results) {
            final name = place['name'].toString();
            final placeId = place['place_id'] as String;

            // Skip veterinary facilities and duplicates
            if (name.toLowerCase().contains('vet') ||
                name.toLowerCase().contains('animal') ||
                name.toLowerCase().contains('pet') ||
                existingPlaceIds.contains(placeId)) {
              continue;
            }

            existingPlaceIds.add(placeId);
            final loc = place['geometry']['location'];
            final address = place['vicinity'];
            final latLng = LatLng(loc['lat'], loc['lng']);
            final rating = place['rating']?.toString() ?? 'N/A';
            final isOpen = place['opening_hours']?['open_now'];
            final distance = _calculateDistance(_currentLocation!, latLng);

            final hospital = {
              'name': name,
              'location': latLng,
              'address': address,
              'rating': rating,
              'isOpen': isOpen,
              'place_id': placeId,
              'distance': distance,
            };

            newHospitals.add(hospital);
            newMarkers.add(
              Marker(
                markerId: MarkerId(placeId),
                position: latLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: name,
                  snippet: '${distance.toStringAsFixed(1)} km • $address',
                ),
                onTap: () => _showHospitalDetails(hospital),
              ),
            );
          }

          // Sort and update UI with new results
          newHospitals.sort((a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double));

          setState(() {
            _markers = newMarkers;
            _hospitals = newHospitals;
            _filteredHospitals = newHospitals;
          });

          if (nextPageToken != null) {
            await Future.delayed(const Duration(seconds: 2));
          }
        } else {
          print('Failed to fetch hospitals: ${data['status']}');
          break;
        }
      } while (nextPageToken != null);
    } catch (e) {
      print('Error in _fetchHospitalsWithRadius: $e');
    }
  }

  void _showHospitalDetails(Map<String, dynamic> hospital) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_hospital, color: primaryBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hospital['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospital['address'] ?? 'Address not available',
                        style:
                        const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        '${hospital['distance'].toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  hospital['isOpen'] == true
                      ? Icons.check_circle
                      : Icons.access_time,
                  color:
                  hospital['isOpen'] == true ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  hospital['isOpen'] == true
                      ? 'Open Now'
                      : 'Status not available',
                  style: TextStyle(
                    color: hospital['isOpen'] == true
                        ? Colors.green
                        : Colors.orange,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (hospital['rating'] != 'N/A') ...[
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    hospital['rating'],
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _moveToLocation(hospital['location']);
                    },
                    icon: const Icon(Icons.location_searching,
                        color: Colors.white),
                    label: const Text(
                      'Show on Map',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchDirections(hospital['location']),
                    icon: const Icon(Icons.directions, color: primaryBlue),
                    label: const Text(
                      'Directions',
                      style: TextStyle(color: primaryBlue),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryBlue,
                      side: const BorderSide(color: primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Nearest Hospitals",
          style: TextStyle(color: primaryBlue),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryBlue),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterHospitals,
              decoration: InputDecoration(
                hintText: 'Search hospitals...',
                prefixIcon: const Icon(Icons.search, color: primaryBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryBlue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryBlue, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(color: primaryBlue))
                : _errorMessage != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchLocationAndHospitals,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation!,
                    zoom: _currentZoom,
                  ),
                  markers: _markers,
                  onMapCreated: (controller) =>
                      _controller.complete(controller),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  right: 16,
                  bottom: 280,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: "btn1",
                        mini: true,
                        backgroundColor: primaryBlue,
                        onPressed: () =>
                            _moveToLocation(_currentLocation!),
                        child:
                        const Icon(Icons.my_location, size: 20),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: "btn2",
                        mini: true,
                        backgroundColor: primaryBlue,
                        onPressed: () => _zoomMap(true),
                        child: const Icon(Icons.add, size: 20),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: "btn3",
                        mini: true,
                        backgroundColor: primaryBlue,
                        onPressed: () => _zoomMap(false),
                        child: const Icon(Icons.remove, size: 20),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: "btn4",
                        mini: true,
                        backgroundColor: primaryBlue,
                        onPressed: _isRefreshing
                            ? null
                            : () {
                          setState(() => _isRefreshing = true);
                          _fetchLocationAndHospitals();
                        },
                        child: _isRefreshing
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.refresh, size: 20),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: _filteredHospitals.isEmpty
                        ? const Center(
                      child: Text(
                        'No hospitals found nearby',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey),
                      ),
                    )
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      itemCount: _filteredHospitals.length,
                      itemBuilder: (context, index) {
                        final hospital =
                        _filteredHospitals[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () =>
                                _showHospitalDetails(hospital),
                            borderRadius:
                            BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons.local_hospital,
                                          color: primaryBlue,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          hospital['name'],
                                          style:
                                          const TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${hospital['distance'].toStringAsFixed(1)} km',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontWeight:
                                          FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons.location_on,
                                          color: Colors.grey,
                                          size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          hospital['address'] ??
                                              '',
                                          style:
                                          const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}