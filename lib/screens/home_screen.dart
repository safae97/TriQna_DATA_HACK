
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Notice we're using latlong2 package
import '../models/user_model.dart';
import '../models/road_issue.dart';
import '../services/auth_service.dart';
import 'user_avatar_widget.dart';
import 'login_screen.dart';
import 'report_issue_screen.dart';




class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  MapController _mapController = MapController();
  final List<Marker> _markers = [];
  LatLng _userLocation = LatLng(37.42796133580664, -122.085749655962); // Default location
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  List<RoadIssue> _userReports = [];
  Map<String, dynamic>? _userInfo;
  bool _mapReady = false;

  AppUser? _currentUser;
  @override
  void initState() {
    super.initState();
    // Initialize controllers and data
    _tabController = TabController(length: 2, vsync: this);

    // Start initial data loading
    _initData();
  }

  Future<void> _initData() async {
    try {
      // First request permissions and get location in parallel with loading user data
      await Future.wait([
        _requestLocationPermission().then((_) => _getCurrentLocation()),
        _loadUserInfo(),
        _loadUserReports(),
      ]);

      // Now that we have location, load map issues
      await _loadIssues();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _refreshAllData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _getCurrentLocation(),
      _loadIssues(),
      _loadUserReports(),
      _loadUserInfo(),
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      String? userId = _authService.currentUser?.uid;
      if (userId != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists && mounted) {
          setState(() {
            _userInfo = userDoc.data() as Map<String, dynamic>;
            _currentUser = AppUser(
              uid: userId,
              email: _userInfo?['email'] ?? '',
              ecoPoints: _userInfo?['ecoPoints'] ?? 0,
            );
          });
        }
      }
    } catch (e) {
      print('Error loading user info: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user info: $e')),
        );
      }
    }
  }

  Future<void> _loadUserReports() async {
    try {
      String? userId = _authService.currentUser?.uid;
      if (userId != null) {
        QuerySnapshot snapshot = await _firestore
            .collection('roadIssues')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .get();

        if (mounted) {
          setState(() {
            _userReports = snapshot.docs
                .map((doc) => RoadIssue.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                .toList();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userReports = [];
          });
        }
      }
    } catch (e) {
      print('Error loading user reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user reports: $e')),
        );
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      if (status.isDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required for better experience')),
        );
      }
    } catch (e) {
      print('Error requesting location permission: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });

        // Only move the map if it's ready
        if (_mapReady && _mapController != null) {
          _mapController.move(_userLocation, 15);
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _loadIssues() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('roadIssues').get();

      if (mounted) {
        _markers.clear();

        // Add user location marker
        _markers.add(
          Marker(
            point: _userLocation,
            width: 40,
            height: 40,
            child: GestureDetector(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.person_pin_circle,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        );

        // Add issue markers
        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          RoadIssue issue = RoadIssue.fromMap(data, doc.id);

          _markers.add(
            Marker(
              point: LatLng(issue.latitude, issue.longitude),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showIssueDetails(issue),
                child: Container(
                  decoration: BoxDecoration(
                    color: _getColorForIssueType(issue.type).withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.report_problem,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          );
        }

        // Update UI
        setState(() {});
      }
    } catch (e) {
      print('Error loading issues: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading issues: $e')),
        );
      }
    }
  }

  Color _getColorForIssueType(String issueType) {
    switch (issueType.toLowerCase()) {
      case 'pothole':
        return Colors.red;
      case 'damaged road':
        return Colors.orange;
      case 'missing sign':
        return Colors.yellow[700] ?? Colors.yellow;
      default:
        return Colors.purple;
    }
  }

  void _showIssueDetails(RoadIssue issue) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(issue.type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(issue.description),
              const SizedBox(height: 8),
              if (issue.imageUrl != null)
                Image.network(issue.imageUrl!, height: 150),
              const SizedBox(height: 12),
              Text("Verified by: ${issue.verificationCount} users"),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.thumb_up),
                    label: const Text("Still there"),
                    onPressed: () async {
                      await _verifyIssue(issue.id, true);
                      Navigator.pop(context);
                      await _loadIssues();
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.thumb_down),
                    label: const Text("Not anymore"),
                    onPressed: () async {
                      await _verifyIssue(issue.id, false);
                      Navigator.pop(context);
                      await _loadIssues();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  Future<void> _verifyIssue(String issueId, bool isUpvote) async {
    DocumentReference issueRef = _firestore.collection('roadIssues').doc(issueId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(issueRef);

      if (!snapshot.exists) return;

      int currentCount = snapshot.get('verificationCount') ?? 0;
      int updatedCount = isUpvote ? currentCount + 1 : (currentCount > 0 ? currentCount - 1 : 0);

      transaction.update(issueRef, {'verificationCount': updatedCount});
    });
  }




  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }



  Widget _buildUserProfile() {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Replace previous user card with UserAvatarWidget
            UserAvatarWidget(user: _currentUser!),

            const SizedBox(height: 20),

            // Existing statistics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(_userReports.length.toString(), 'Reports'),
                _buildStatColumn(
                    _getTotalVerifications().toString(), 'Verifications'),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              'Your Reports',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            _userReports.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.report_outlined, size: 60, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'You haven\'t reported any issues yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _userReports.length,
              itemBuilder: (context, index) {
                final report = _userReports[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _showIssueDetails(report),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (report.imageUrl != null && report.imageUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                report.imageUrl!,
                                height: 80,
                                width: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 80,
                                  width: 80,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 80,
                              width: 80,
                              decoration: BoxDecoration(
                                color: _getColorForIssueType(report.type),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.report_problem, color: Colors.white),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.type,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  report.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDate(report.timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.verified_user, size: 14),
                                        const SizedBox(width: 4),
                                        Text('${report.verificationCount}'),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Report Issue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportIssueScreen(userLocation: _userLocation),
                    ),
                  ).then((_) => _refreshAllData());
                },
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Report Issue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getUserInitials() {
    String name = _userInfo?['name'] ?? '';
    if (name.isEmpty) return '?';

    List<String> nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  int _getTotalVerifications() {
    return _userReports.fold(0, (total, report) => total + report.verificationCount);
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation,
            initialZoom: 15.0,
            onMapReady: () {
              setState(() {
                _mapReady = true;
              });
              // Now it's safe to move the map
              _mapController.move(_userLocation, 15.0);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(markers: _markers),
          ],
        ),
        Positioned(
          bottom: 90,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            mini: true,
            onPressed: () async {
              await _getCurrentLocation();
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _legendItem(Colors.red, 'Pothole'),
              const SizedBox(width: 12),
              _legendItem(Colors.orange, 'Damaged Road'),
              const SizedBox(width: 12),
              _legendItem(Colors.purple, 'Damaged Sign'),
              const SizedBox(width: 12),
              _legendItem(Colors.blue, 'Your Location'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'triQna',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF3498DB),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshAllData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              AuthService().signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.map, color: Colors.white),
              text: 'Map',
            ),
            Tab(
              icon: Icon(Icons.person, color: Colors.white),
              text: 'Profile',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMapView(),
          _buildUserProfile(),
        ],
      ),
    );
  }
}