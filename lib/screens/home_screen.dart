import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/road_issue.dart';
import 'report_issue_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  LatLng? _userLocation;
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    await _requestLocationPermission();
    await _getCurrentLocation();
    await _loadIssues();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required for better experience')),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _loadIssues() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('roadIssues').get();
      setState(() {
        _markers.clear();
        if (_userLocation != null) {
          _markers.add(
            Marker(
              markerId: const MarkerId('userLocation'),
              position: _userLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'Your Location'),
            ),
          );
        }
        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          RoadIssue issue = RoadIssue.fromMap(data, doc.id);
          _markers.add(
            Marker(
              markerId: MarkerId(issue.id),
              position: LatLng(issue.latitude, issue.longitude),
              icon: _getMarkerIcon(issue.type),
              infoWindow: InfoWindow(
                title: issue.type,
                snippet: issue.description,
                onTap: () => _showIssueDetails(issue),
              ),
            ),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading issues: $e')),
      );
    }
  }

  BitmapDescriptor _getMarkerIcon(String issueType) {
    switch (issueType.toLowerCase()) {
      case 'pothole':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'damaged road':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'missing sign':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }

  void _showIssueDetails(RoadIssue issue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  issue.type,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Reported on ${_formatDate(issue.timestamp)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(issue.description),
            const SizedBox(height: 10),
            if (issue.imageUrl != null && issue.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  issue.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.grey[300],
                    alignment: Alignment.center,
                    child: const Text('Image not available'),
                  ),
                ),
              ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Icon(Icons.directions_walk, size: 16),
                const SizedBox(width: 5),
                Text('Transportation mode: ${issue.transportMode}'),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Icon(Icons.verified_user, size: 16),
                const SizedBox(width: 5),
                Text('Verifications: ${issue.verificationCount}'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _verifyIssue(issue.id),
                child: const Text('Verify This Issue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _verifyIssue(String issueId) async {
    try {
      await _firestore.collection('roadIssues').doc(issueId).update({
        'verificationCount': FieldValue.increment(1),
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue verified successfully!')),
      );
      await _loadIssues();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying issue: $e')),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'triQna',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3498DB),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadIssues,
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              // Navigate to profile screen
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_userLocation != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _userLocation!,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              markers: _markers,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            )
          else
            const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              mini: true,
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(_userLocation!),
                );
              },
              child: const Icon(Icons.my_location, color: Color(0xFF3498DB)),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildLegend(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_userLocation != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReportIssueScreen(userLocation: _userLocation!),
              ),
            ).then((_) => _loadIssues());
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please wait for location to load')),
            );
          }
        },
        backgroundColor: const Color(0xFF3498DB),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Report Issue'),
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _legendItem(Colors.red, 'Pothole'),
            _legendItem(Colors.orange, 'Damaged Road'),
            _legendItem(Colors.yellow, 'Missing Sign'),
            _legendItem(Colors.blue, 'Your Location'),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}